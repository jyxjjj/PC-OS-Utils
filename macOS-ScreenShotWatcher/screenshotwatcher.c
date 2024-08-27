#include <CoreServices/CoreServices.h>
#include <ApplicationServices/ApplicationServices.h>
#include <pthread.h>
#include <stdio.h>
#include <libgen.h>

static CFDataRef read_file_to_data(const char *path)
{
    FILE *file = fopen(path, "rb");
    if (!file)
        return NULL;
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    UInt8 *buffer = (UInt8 *)malloc(length);
    if (!buffer)
    {
        fclose(file);
        return NULL;
    }
    fread(buffer, 1, length, file);
    fclose(file);
    CFDataRef data = CFDataCreate(NULL, buffer, length);
    free(buffer);
    return data;
}

static void copy_data_to_clipboard(CFDataRef data)
{
    PasteboardRef clipboard;
    PasteboardCreate(kPasteboardClipboard, &clipboard);
    PasteboardClear(clipboard);
    PasteboardSynchronize(clipboard);

    PasteboardPutItemFlavor(clipboard, (PasteboardItemID)1, CFSTR("public.png"), data, 0);
    CFRelease(clipboard);
}

static int ask_user_confirmation(const char *filename)
{
    CFStringRef message = CFStringCreateWithFormat(NULL, NULL, CFSTR("Do you want to move %s to Trash?"), filename);
    CFOptionFlags responseFlags;
    CFUserNotificationDisplayAlert(
        0, kCFUserNotificationNoteAlertLevel,
        NULL, NULL, NULL,
        CFSTR("Confirmation"),
        message,
        CFSTR("Yes"), CFSTR("No"), NULL,
        &responseFlags);
    CFRelease(message);
    return responseFlags == kCFUserNotificationDefaultResponse;
}

static int move_to_trash(const char *path)
{
    char trash_path[1024];
    snprintf(trash_path, sizeof(trash_path), "%s/.Trash/%s", getenv("HOME"), basename((char *)path));
    return rename(path, trash_path);
}

static void callback(__unused ConstFSEventStreamRef streamRef,
                     __unused void *clientCallBackInfo,
                     size_t numEvents,
                     void *eventPaths,
                     __unused const FSEventStreamEventFlags eventFlags[],
                     __unused const FSEventStreamEventId eventIds[])
{
    char **paths = eventPaths;
    for (size_t i = 0; i < numEvents; i++)
    {
        char *path = paths[i];
        char *filename = basename(path);
        if (filename[0] == '.')
            continue;
        if (strncmp(filename, "Screenshot", 10) != 0)
            continue;
        if (strlen(filename) < 4 || strcmp(filename + strlen(filename) - 4, ".png") != 0)
            continue;
        printf("%s\n", paths[i]);
        CFDataRef data = read_file_to_data(path);
        if (data)
        {
            copy_data_to_clipboard(data);
            CFRelease(data);
            printf("Copied %s to clipboard\n", path);
            if (ask_user_confirmation(filename))
            {
                if (move_to_trash(path) == 0)
                {
                    printf("Moved %s to Trash\n", path);
                }
            }
        }
    }
}

int main(void)
{
    char *home = getenv("HOME");
    if (!home)
        return -1;
    CFStringRef path = CFStringCreateWithFormat(NULL, NULL, CFSTR("%s/Downloads/ScreenShots"), home);
    CFArrayRef paths = CFArrayCreate(NULL, (const void **)&path, 1, NULL);
    CFAbsoluteTime latency = 0.5;
    FSEventStreamRef stream = FSEventStreamCreate(
        NULL,
        &callback,
        NULL,
        paths,
        kFSEventStreamEventIdSinceNow,
        latency,
        kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents);
    if (stream == NULL)
        return -1;
    dispatch_queue_t queue = dispatch_queue_create("com.desmg.screenshot.watcher", NULL);
    FSEventStreamSetDispatchQueue(stream, queue);
    FSEventStreamStart(stream);
    while (TRUE)
    {
        static char input_buf[128];
        fgets(input_buf, sizeof(input_buf), stdin);
    }
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
    FSEventStreamRelease(stream);
    dispatch_release(queue);
    return 0;
}
