/*
 * fsevents-wake FOLDER
 *
 * Watches FOLDER through FSEvents for changes that can concern GTA V Enhanced's arguments: a file
 * named GTA5_Enhanced.exe or commandline.txt (any case) changed, a folder created or renamed (an
 * installer can move a whole tree into place), or events dropped or coalesced (anything may have
 * changed). It prints "ready" once it watches, then "wake" for such a change. A line read from
 * standard input acknowledges the last line printed: until then, changes only mark that one more
 * "wake" is due, printed with the acknowledgement, so a burst of changes costs its reader one more
 * pass, not one per batch. It ends when standard input closes (the reader is done), when a line
 * cannot be written (the reader is gone), or when it is killed.
 *
 * gta5-enhanced-mac runs it while a Wine session runs and writes commandline.txt after each line
 * ("ready" included, so a change made before the watch started is not missed), then acknowledges;
 * "ready" too must be acknowledged before any "wake" comes.
 *
 * Built by .github/workflows/build-engine.yml and shipped in the engine release as tools/fsevents-wake.
 * MIT licence (tools/LICENSE in the release, LICENSE in the repository).
 */
#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

/* Touched only on the serial queue. */
static int awaiting_ack = 1; /* "ready" is printed unacknowledged */
static int wake_due;

static void print_line(const char *line)
{
	/* The reader is gone: the watch has no one to tell. */
	if (puts(line) == EOF || fflush(stdout) == EOF)
		exit(1);
}

static void changed(void)
{
	if (awaiting_ack) {
		wake_due = 1;
		return;
	}
	print_line("wake");
	awaiting_ack = 1;
}

static void acknowledged(void)
{
	awaiting_ack = 0;
	if (wake_due) {
		wake_due = 0;
		changed();
	}
}

static int interesting_name(const char *path)
{
	const char *base = strrchr(path, '/');
	base = base ? base + 1 : path;
	return !strcasecmp(base, "GTA5_Enhanced.exe") || !strcasecmp(base, "commandline.txt");
}

static void callback(ConstFSEventStreamRef stream, void *info, size_t count, void *paths,
		     const FSEventStreamEventFlags flags[], const FSEventStreamEventId ids[])
{
	(void)stream;
	(void)info;
	(void)ids;
	const FSEventStreamEventFlags rescan = kFSEventStreamEventFlagMustScanSubDirs |
					       kFSEventStreamEventFlagUserDropped |
					       kFSEventStreamEventFlagKernelDropped;
	char **names = paths;
	for (size_t i = 0; i < count; i++) {
		FSEventStreamEventFlags f = flags[i];
		int folder_arrived = (f & kFSEventStreamEventFlagItemIsDir) &&
				     (f & (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRenamed));
		if ((f & rescan) || folder_arrived || interesting_name(names[i])) {
			changed();
			return;
		}
	}
}

int main(int argc, char **argv)
{
	if (argc != 2) {
		fprintf(stderr, "usage: fsevents-wake FOLDER\n");
		return 2;
	}
	signal(SIGPIPE, SIG_DFL);
	CFStringRef folder = CFStringCreateWithCString(NULL, argv[1], kCFStringEncodingUTF8);
	if (!folder) {
		fprintf(stderr, "fsevents-wake: the folder's name is not UTF-8\n");
		return 1;
	}
	CFArrayRef watched = CFArrayCreate(NULL, (const void **)&folder, 1, &kCFTypeArrayCallBacks);
	/* Latency 0 with NoDefer: each batch is delivered as soon as FSEvents has it, so the arguments
	 * are written as soon as the game's files land. */
	FSEventStreamRef stream = FSEventStreamCreate(
		NULL, callback, NULL, watched, kFSEventStreamEventIdSinceNow, 0,
		kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer);
	if (!stream) {
		fprintf(stderr, "fsevents-wake: could not watch %s\n", argv[1]);
		return 1;
	}
	dispatch_queue_t queue = dispatch_queue_create("fsevents-wake", DISPATCH_QUEUE_SERIAL);
	FSEventStreamSetDispatchQueue(stream, queue);
	/* Started on the queue, so no callback runs before "ready" is out. */
	dispatch_sync(queue, ^{
		if (!FSEventStreamStart(stream)) {
			fprintf(stderr, "fsevents-wake: could not start watching %s\n", argv[1]);
			exit(1);
		}
		print_line("ready");
	});
	/* Acknowledgements, each newline one, read on this thread while the queue handles events. */
	char buffer[256];
	ssize_t n;
	for (;;) {
		n = read(STDIN_FILENO, buffer, sizeof buffer);
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			break;
		ssize_t acks = 0;
		for (ssize_t i = 0; i < n; i++)
			acks += buffer[i] == '\n';
		dispatch_sync(queue, ^{
			for (ssize_t i = 0; i < acks; i++)
				acknowledged();
		});
	}
	/* The reader ended (or reading failed): so does the watch, its stream stopped on its queue
	 * first so no callback runs while the process exits. */
	dispatch_sync(queue, ^{
		FSEventStreamStop(stream);
		FSEventStreamInvalidate(stream);
	});
	FSEventStreamRelease(stream);
	return n == 0 ? 0 : 1;
}
