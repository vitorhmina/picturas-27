"""PictuRAS video_subtitles tool: automatic subtitles: speech recognition and burned-in captions.

Consumes video_subtitles_queue; the worker itself is shared by the video tools
(video_common/stage_worker.py).
"""
from stage_worker import main

if __name__ == "__main__":
    main("subtitles")
