local Check=require('auth_check')
function on_load(ctx)Check.load(ctx)end
function on_draw(ctx,g)Check.draw(ctx,g)end
function on_input(ctx,ev)return Check.input(ctx,ev)end
function on_tick(ctx)Check.tick(ctx)end
function on_pause(ctx)Check.pause(ctx)end
function on_resume(ctx)Check.resume(ctx)end
function on_leave(ctx)Check.leave(ctx)end
