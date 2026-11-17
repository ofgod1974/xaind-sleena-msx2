-- Research capture: forced position/health; NOT a gameplay timing reference.
local planet=tonumber(os.getenv("XAIN_PLANET") or "0")
local root=(os.getenv("XAIN_CAPTURE_ROOT") or "work/map-reference/").."planet-"..planet.."/"
local sp=manager.machine.devices[":maincpu"].spaces["program"]
local fields={};for _,p in pairs(manager.machine.ioport.ports) do for name,f in pairs(p.fields) do fields[name]=f end end
local frame=0
local scroll={0,0,0,0,0,0,0,0,0}
local hook=sp:install_write_tap(0x3a00,0x3a0f,"map-scroll",function(a,v,m) if a<=0x3a07 then scroll[a-0x3a00+1]=v end;if a==0x3a0f then scroll[9]=v&7 end end)
local log=io.open(root.."frames.csv","w");log:write("frame,planet,mode,phase,x,y,cameraX,cameraY\n")
local function word(a) return sp:read_u8(a)*256+sp:read_u8(a+1) end
local function putword(a,v) sp:write_u8(a,(v>>8)&255);sp:write_u8(a+1,v&255) end
local function key(n,on) if fields[n] then fields[n]:set_value(on and 1 or 0) end end
emu.register_frame_done(function()
 if not hook then return end
 frame=frame+1
 key("Coin 1",frame>=300 and frame<310);key("1 Player Start",frame>=360 and frame<370)
 key("P1 Button 1",frame>=1600 and frame<1610 or frame>2500 and frame%12<3)
 key("P1 Right",frame>2500)
 if frame>=1400 and frame<=2150 then sp:write_u8(0x48,planet) end
 if frame>2500 and sp:read_u8(0x52)==2 then
  sp:write_u8(0x56,16);sp:write_u8(0x60,7);sp:write_u8(0x1935,0x59)
  putword(0x447,word(0x447)+2)
  putword(0x44a,word(0x5c)+128)
 end
 if frame>2300 and frame%16==0 then
  local f=io.open(root.."state-"..frame..".bin","wb");f:write(sp:read_range(0,0x3fff,8));f:close()
  f=io.open(root.."scroll-"..frame..".bin","wb");f:write(string.char(table.unpack(scroll)));f:close()
  f=io.open(root.."palette-"..frame..".bin","wb");local p=manager.machine.palettes[":palette"];for i=0,511 do local c=p:pen_color(i);f:write(string.char((c>>16)&255,(c>>8)&255,c&255)) end;f:close()
 end
 if frame%240==0 then
  log:write(frame..","..sp:read_u8(0x48)..","..sp:read_u8(0x53)..","..sp:read_u8(0x52)..","..word(0x447)..","..word(0x44a)..","..word(0x59)..","..word(0x5c).."\n");log:flush()
  manager.machine.screens[":screen"]:snapshot(root.."scene-"..frame..".png")
 end
 if frame==6600 then log:close();manager.machine:exit() end
end)
