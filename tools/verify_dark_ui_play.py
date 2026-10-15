"""Read-only Play-mode UI smoke checks for the live Chest RNG Studio session.

Uses Studio MCP's client console to inspect the actual player GUI and to send
ordinary keyboard/mouse events through the Studio input manager. Stops Play on exit.
Does not save or publish the experience.
"""
from __future__ import annotations

import base64
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, "/private/tmp")
from chest_rng_studio_sync_20261014 import Client, studio_info  # type: ignore

OUT = Path("/private/tmp/chest_dark_ui_play_20261014")


def lua(client: Client, studio_id: str, code: str, timeout: int = 65) -> dict:
    return json.loads(client.tool("execute_luau", {
        "studio_id": studio_id, "datamodel_type": "Client", "code": code}, timeout=timeout))


def capture(client: Client, studio_id: str, name: str) -> str | None:
    response = client.request("tools/call", {
        "name": "screen_capture", "arguments": {
            "studio_id": studio_id, "capture_id": name}}, timeout=60)
    if response.get("isError"):
        print("CAPTURE_ERROR", name, str(response.get("content", []))[:500], flush=True)
        return None
    for part in response.get("content", []):
        if part.get("type") == "image":
            extension = "jpg" if "jpeg" in part.get("mimeType", "") else "png"
            path = OUT / f"{name}.{extension}"
            path.write_bytes(base64.b64decode(part["data"]))
            return str(path)
    return None


INFO = '''
local p=game:GetService("Players").LocalPlayer
if not p then return {error="No LocalPlayer"} end
local pg=p:WaitForChild("PlayerGui",20)
if not pg then return {error="No PlayerGui"} end
local gui=pg:WaitForChild("ChestRPGUI",20)
if not gui then return {error="No ChestRPGUI"} end
local nav=gui:FindFirstChild("QuickMenu")
local overlay=gui:FindFirstChild("MenuOverlay")
local sidebar=overlay and overlay:FindFirstChild("NavigationSidebar",true)
local body=overlay and overlay:FindFirstChild("Body",true)
local buttons={}
for _,key in {"Inventory","Chest","Regions","Rebirth","Settings","EquipBest"} do
 local btn=nav and nav:FindFirstChild(key.."Button")
 buttons[key]={exists=btn~=nil,position=btn and tostring(btn.AbsolutePosition),size=btn and tostring(btn.AbsoluteSize)}
end
local tabs={}
for _,key in {"Inventory","Chest","Regions","Rebirth","Settings"} do
 local btn=sidebar and sidebar:FindFirstChild(key.."Tab")
 tabs[key]=btn and {size=tostring(btn.AbsoluteSize),position=tostring(btn.AbsolutePosition),
  hasLabel=btn:FindFirstChild("Label")~=nil} or {missing=true}
end
return {guiEnabled=gui.Enabled,viewport=tostring(gui.AbsoluteSize),menuVisible=overlay and overlay.Visible,
 hud=gui:FindFirstChild("Counters")~=nil,powerDock=gui:FindFirstChild("PowerDock")~=nil,
 nav=buttons,sidebar=sidebar~=nil,tabs=tabs,body=body~=nil,
 loaded=p:GetAttribute("DataReady"),player=p.Name}
'''

OPEN = '''
local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild("ChestRPGUI")
if not gui then return {error="GUI missing"} end
local ok,err=pcall(function()
 local vim=game:GetService("VirtualInputManager")
 vim:SendKeyEvent(true,Enum.KeyCode.M,false,game)
 task.wait(.12)
 vim:SendKeyEvent(false,Enum.KeyCode.M,false,game)
end)
task.wait(.45)
local overlay=gui:FindFirstChild("MenuOverlay")
local body=overlay and overlay:FindFirstChild("Body",true)
local title=overlay and overlay:FindFirstChild("NavigationSidebar",true)
local armory=body and body:FindFirstChild("ArmoryContent",true)
return {sent=ok,sendError=if ok then nil else tostring(err),
 opened=overlay and overlay.Visible,armory=armory~=nil,
 bodyCount=body and #body:GetChildren() or 0,
 title=gui:FindFirstChild("InventoryTab",true)~=nil,
 modalSize=tostring(overlay and overlay:FindFirstChildWhichIsA("Frame") and overlay:FindFirstChildWhichIsA("Frame").AbsoluteSize),
 sidebar=title~=nil}
'''

CLICK = '''
local key = %s
local gui=game.Players.LocalPlayer.PlayerGui:FindFirstChild("ChestRPGUI")
local overlay=gui and gui:FindFirstChild("MenuOverlay")
local tab=overlay and overlay:FindFirstChild(key.."Tab",true)
if not tab then return {error="Tab missing: "..key} end
local pos=tab.AbsolutePosition+tab.AbsoluteSize/2
local ok,err=pcall(function()
 local vim=game:GetService("VirtualInputManager")
 vim:SendMouseButtonEvent(pos.X,pos.Y,0,true,game,0)
 task.wait(.11)
 vim:SendMouseButtonEvent(pos.X,pos.Y,0,false,game,0)
end)
task.wait(.35)
local active=overlay:FindFirstChild("ActiveMarker",true)
local body=overlay:FindFirstChild("Body",true)
local heading=overlay:FindFirstChild("NavigationSidebar",true)
local tabMarker=tab:FindFirstChild("ActiveMarker")
local title=overlay:FindFirstChild("NavigationSidebar",true)
return {tab=key,sent=ok,sendError=if ok then nil else tostring(err),
 menuVisible=overlay.Visible,activeMarker=tabMarker and tabMarker.Visible,
 bodyChildCount=body and #body:GetChildren() or 0,
 tabPosition=tostring(pos),hasSidebar=heading~=nil}
'''


def main() -> None:
    OUT.mkdir(exist_ok=True)
    c = Client()
    sid = None
    started = False
    report: dict = {}
    try:
        sid = studio_info(c)
        current = c.tool("get_studio_state", {"studio_id": sid})
        print("INITIAL_STATE", current, flush=True)
        if "Current Studio Mode: Edit" not in current:
            raise RuntimeError("Expected Studio Edit mode; refusing to disturb existing Play session")
        print("PLAY_START", c.tool("start_stop_play", {"studio_id": sid, "is_start": True}, timeout=90), flush=True)
        started = True
        for attempt in range(20):
            current = c.tool("get_studio_state", {"studio_id": sid})
            if "Client" in current:
                break
            time.sleep(.8)
        print("PLAY_STATE", current, flush=True)
        if "Client" not in current:
            raise RuntimeError("No Client DataModel became available")
        report["initial"] = lua(c, sid, INFO, timeout=85)
        print("GUI_INITIAL", json.dumps(report["initial"]), flush=True)
        report["hudCapture"] = capture(c, sid, "dark_ui_hud")
        report["open"] = lua(c, sid, OPEN)
        print("OPEN_INVENTORY", json.dumps(report["open"]), flush=True)
        report["inventoryCapture"] = capture(c, sid, "dark_ui_inventory")
        report["tabs"] = {}
        if report["open"].get("opened"):
            for key in ("Chest", "Regions", "Rebirth", "Settings", "Inventory"):
                result = lua(c, sid, CLICK % json.dumps(key))
                report["tabs"][key] = result
                print("TAB", json.dumps(result), flush=True)
                if key == "Chest":
                    report["chestCapture"] = capture(c, sid, "dark_ui_chest")
        report["console"] = c.tool("get_console_output", {"studio_id": sid}, timeout=45)
        print("CONSOLE", report["console"][-7500:], flush=True)
    finally:
        if sid and started:
            try:
                print("PLAY_STOP", c.tool("start_stop_play", {"studio_id": sid, "is_start": False}, timeout=90), flush=True)
            except Exception as exc:
                print("PLAY_STOP_ERROR", str(exc), flush=True)
        if report:
            (OUT / "play_report.json").write_text(json.dumps(report, indent=2))
            print("REPORT", str(OUT / "play_report.json"), flush=True)
        c.close()


if __name__ == "__main__":
    main()
