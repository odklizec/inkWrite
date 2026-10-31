local App = require("domain.app")
function on_load(ctx) App.load(ctx) end
function on_draw(ctx, g) App.draw(ctx, g) end
function on_input(ctx, ev) return App.input(ctx, ev) end
function on_tick(ctx, dt) App.tick(ctx, dt) end
function on_pause(ctx) App.pause(ctx) end
function on_resume(ctx) App.resume(ctx) end
function on_leave(ctx) App.leave(ctx) end
