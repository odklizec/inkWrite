local UI=require('domain.sync_ui')
local GuideQR=require('domain.github_guide_qr')
local n=0
local function check(v,message)n=n+1;assert(v,message)end
check(GuideQR.url=='https://github.com/odklizec/inkWrite/blob/main/docs/GITHUB-SETUP-GUIDE.md',
  'guide points directly to the illustrated setup instructions in the public repository')

for _,dims in ipairs({{480,800},{800,480}})do
  for _,line in ipairs({24,44})do
    local ctx={screen={width=dims[1],height=dims[2],occlusion={left=8,right=8,top=8,bottom=8}},
      state={},invalidate=function()end,net={request=function()error('offline help must not request the network')end}}
    local font={line_height=line}
    local function key(ui,code)
      ui:input(ctx,{type='key',code=code,phase='down'})
    end
    local function select(ui,row)
      ui.focus=row;ui:tick(ctx);key(ui,'Enter')
    end
    local function verify_guide(ui)
      local text,rects={},{}
      local g={
        clear=function()end,line=function()end,
        text=function(_,_,_,s)text[s]=true end,
        text_box=function(_,_,_,_,_,s)text[(s:gsub('\n',''))]=true end,
        rect=function(_,x,y,w,h,o)
          rects[#rects+1]={x=x,y=y,w=w,h=h,fill=o.fill,color=o.color}
        end
      }
      ui:draw(ctx,g)
      check(text['Setup instructions'] and text[GuideQR.url] and text.Back and not text.Prev and not text.Next,
        'guide has a readable fallback URL and a Back control')
      local q=rects[1]
      check(q and q.fill and q.color==0 and q.w==q.h and q.w>=GuideQR.size*2,
        'guide has a high contrast, integer-scaled QR code')
      check(q.x>=8 and q.y>=8 and q.x+q.w<=dims[1]-8 and q.y+q.h<dims[2]-74,
        'QR fits above the footer in both orientations and font sizes')
      local scale=q.w//GuideQR.size
      check(#rects==#GuideQR.rects+1,'guide renders its own QR matrix')
      for i,r in ipairs(GuideQR.rects)do
        local px=rects[i+1]
        check(px.x==q.x+r[1]*scale and px.y==q.y+r[2]*scale and px.w==r[3]*scale and px.h==scale
          and px.fill and px.color==15,'rendered QR runs match the generated code')
      end
    end

    local ui=UI.new({},font,font)
    ui:open(ctx);select(ui,7)
    check(ui.page=='help','GitHub Help opens')
    check(ui.focus==1,'Setup instructions is the first Help row')
    key(ui,'Enter');verify_guide(ui)
    ui:input(ctx,{type='key',key='back',phase='up'})
    check(ui.page=='help' and ui.focus==1,'device Back restores the help menu and selection')
    key(ui,'ArrowDown');key(ui,'ArrowDown')
    check(ui.focus==2,'Help has just Setup instructions and revocation')
    key(ui,'Enter');check(ui.page=='revoke','revocation remains the second Help row')

    ui=UI.new({},font,font,{setup={profiles={}}})
    ui:open(ctx)
    check(ui.setup.active and ui.setup.page=='setup','new users start in GitHub setup')
    select(ui,5);verify_guide(ui)
    key(ui,'Escape')
    check(ui.setup.page=='setup' and ui.focus==5,'Escape returns first-time users to setup')
    key(ui,'ArrowDown');check(ui.focus==5,'first-time setup shows one instructions row')
  end
end
return n
