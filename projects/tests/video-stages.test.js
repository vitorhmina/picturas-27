const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const {
  planVideoStages, assignStageOutputs, stageTool, stageParams, intermediateOutputs,
} = require('../utils/videoStages');

// Same file as Tools/video_common/tests/test_stages.py: both planners must agree.
const PLANS = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'Tools', 'video_common', 'tests', 'stage_plans.json'), 'utf8'));

for (const c of PLANS) {
  test(`stage plan matches the Python planner: ${c.name}`, () => {
    assert.deepEqual(planVideoStages(c.tools, c.preview), c.stages);
  });
}

test('each stage goes to the queue of its own service', () => {
  const stages = planVideoStages([
    { procedure: 'brightness', params: {} },
    { procedure: 'subtitles', params: {} },
    { procedure: 'extract_frames', params: { mode: 'count', count: 2, format: 'png' } },
  ], false);
  assert.deepEqual(stages.map(stageTool), ['video_effects', 'video_subtitles', 'video_frames']);
});

test('only the last stage writes the final output', () => {
  const finalUri = './images/users/u/projects/p/out/clip.mp4';
  const stages = assignStageOutputs(planVideoStages([{ procedure: 'subtitles', params: {} }], false), finalUri, 'job1');
  assert.equal(stages.length, 2);
  assert.equal(stages[1].output, finalUri);
  assert.equal(stages[0].output, './images/users/u/projects/p/out/.video-stages/clip-job1-0.mp4');
  assert.deepEqual(intermediateOutputs(stages), [stages[0].output]);
});

test('stage message carries the stage without its output path', () => {
  const stages = assignStageOutputs(planVideoStages([{ procedure: 'brightness', params: {} }], true), 'out/a.mp4', 'j');
  const params = stageParams(stages, 0, { preview: true, progress: { user: 'u' } });
  assert.equal(params.last, true);
  assert.equal(params.preview, true);
  assert.equal(params.stage.kind, 'effects');
  assert.equal(params.stage.output, undefined);
  assert.deepEqual(params.progress, { user: 'u' });
});

test('planning does not mutate the project pipeline', () => {
  const tools = [{ procedure: 'brightness', params: { brightness: 1 } }];
  const stages = planVideoStages(tools, false);
  stages[0].tools.push({ procedure: 'contrast', params: {} });
  assert.equal(tools.length, 1);
});
