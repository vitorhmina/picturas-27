"""PictuRAS video_frames tool: still-frame extraction from videos (always the last stage).

Consumes video_frames_queue; the worker itself is shared by the video tools
(video_common/stage_worker.py).
"""
from stage_worker import main

if __name__ == "__main__":
    main("frames")
