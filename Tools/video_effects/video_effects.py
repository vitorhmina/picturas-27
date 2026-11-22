"""PictuRAS video_effects tool: frame effects, trim and speed on videos (one decode, one encode).

Consumes video_effects_queue; the worker itself is shared by the video tools
(video_common/stage_worker.py).
"""
from stage_worker import main

if __name__ == "__main__":
    main("effects")
