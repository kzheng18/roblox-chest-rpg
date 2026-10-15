"""Inspect Chest RPG's dark UI in a private Studio Play session.

Checks HUD contrast and uses Studio MCP mouse input to exercise the actual
navigation callbacks. Does not alter source, saves, or publish the place.
"""
from __future__ import annotations

import base64
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, "/private/tmp")
from chest_rng_studio_sync_20261014 import Client, studio_info  # type: ignore

OUT = Path("/private/tmp/chest_dark_ui_navigation_20261014")


def run(client: Client, studio_id: str, code: str) -> dict:
    return json.loads(client.tool("execute_luau", {
        "studio_id": studio_id, "datamodel_type": "Client", "code": code
    }, timeout=85))


def click(client: Client, studio_id: str, instance_path: str) -> str:
    return client.tool("user_mouse_input", {
        "studio_id": studio_id, "datamodel_type": "Client", "actions": [
            {"action": "mouseButtonClick", "mouse_button": "left", "instance_path": instance_path}
        ]
    }, timeout=65)


def capture(client: Client, studio_id: str, tag: str) -> str | None:
    result = client.request("tools/call", {"name": "screen_capture", "arguments": {
        "studio_id": studio_id, "capture_id": tag
    }}, timeout=65)
    if result.get("isError"):
        print("SCREENSHOT_ERROR", tag, str(result.get("content", ""))[:300], flush=True)
        return None
    for item in result.get("content", []):
        if item.get("type") == "image":
            suffix = ".jpg" if "jpeg" in item.get("mimeType", "") else ".png"
            path = OUT / (tag + suffix)
            path.write_bytes(base64.b64decode(item["data"]))
            return str(path)
    return None


INSPECT = '''
local p=game:GetService("Players").LocalPlayer
local g=p and p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("ChestRPGUI")
if not g then return {error="GUI not found"} end
local objective=g:FindFirstChild("NextGoal")
local save=g:FindFirstChild("SaveIndicator")
local overlay=g:FindFirstChild("MenuOverlay")
local title=overlay and overlay:FindFirstChild("ModalTitle",true)
local body=overlay and overlay:FindFirstChild("Body",true)
local tabs={}
for _,name in {"Inventory","Chest","Regions","Rebirth","Settings"} do
 local tab=overlay and overlay:FindFirstChild(name.."Tab",true)
 local active=tab and tab:FindFirstChild("ActiveMarker")
 tabs[name]={exists=tab~=nil,selected=active and active.Visible,
  size=tab and tostring(tab.AbsoluteSize) or ""}
end
local quick=g:FindFirstChild("QuickMenu")
local buttons={}
for _,name in {"Inventory","Chest","Regions","Rebirth","Settings"} do
 local button=quick and quick:FindFirstChild(name.."Button")
 buttons[name]={exists=button~=nil,visible=button and button.Visible,
  pos=button and tostring(button.AbsolutePosition),size=button and tostring(button.AbsoluteSize)}
end
local labels={}
if body then
 for _,desc in body:GetDescendants() do
  if desc:IsA("TextLabel") or desc:IsA("TextButton") then
   if #labels<12 then table.insert(labels,desc.Text) end
  end
 end
end
return {loaded=p:GetAttribute("DataReady"),name=p.Name,enabled=g.Enabled,
 objective={exists=objective~=nil,background=objective and objective.BackgroundTransparency,
  region=objective and objective:FindFirstChildWhichIsA("TextLabel") and objective:FindFirstChildWhichIsA("TextLabel").Text,
  position=objective and tostring(objective.AbsolutePosition),size=objective and tostring(objective.AbsoluteSize)},
 save={exists=save~=nil,background=save and save.BackgroundTransparency,text=save and save.Text},
 overlayVisible=overlay and overlay.Visible,title=title and title.Text,
 bodyChildren=body and #body:GetChildren(),bodySize=body and tostring(body.AbsoluteSize),
 bodyCanvas=body and tostring(body.AbsoluteCanvasSize),labels=labels,
 tabs=tabs,buttons=buttons,viewport=tostring(g.AbsoluteSize)}
'''


def main() -> None:
    OUT.mkdir(exist_ok=True)
    report: dict = {}
    client = Client()
    sid = None
    started = False
    try:
        sid = studio_info(client)
        mode = client.tool("get_studio_state", {"studio_id": sid})
        if "Current Studio Mode: Edit" not in mode:
            raise RuntimeError(f"Expected Edit before starting Play: {mode}")
        print("PLAY_START", client.tool("start_stop_play", {"studio_id": sid, "is_start": True}, timeout=100), flush=True)
        started = True
        for _ in range(25):
            mode = client.tool("get_studio_state", {"studio_id": sid})
            if "Client" in mode:
                break
            time.sleep(.7)
        if "Client" not in mode:
            raise RuntimeError(f"No client model: {mode}")
        report["start"] = run(client, sid, INSPECT)
        print("HUD", json.dumps(report["start"]), flush=True)
        report["hudScreenshot"] = capture(client, sid, "hud")
        report["pages"] = {}
        for name in ("Inventory", "Chest", "Regions", "Rebirth", "Settings"):
            if name == "Inventory":
                target = f"LocalPlayer.PlayerGui.ChestRPGUI.QuickMenu.{name}Button"
            else:
                # Components.Panel creates the unnamed Frame inside MenuOverlay.
                target = f"LocalPlayer.PlayerGui.ChestRPGUI.MenuOverlay.Frame.NavigationSidebar.{name}Tab"
            activation = click(client, sid, target)
            time.sleep(.45)
            inspection = run(client, sid, INSPECT)
            report["pages"][name] = {"activation": activation, "inspection": inspection}
            print("PAGE", name, str(activation)[:180], "title", inspection.get("title"),
                  "visible", inspection.get("overlayVisible"), "labels", inspection.get("labels"), flush=True)
            if inspection.get("overlayVisible"):
                report["pages"][name]["screenshot"] = capture(client, sid, "page_" + name.lower())
            if not inspection.get("overlayVisible") or not inspection.get("tabs", {}).get(name, {}).get("selected"):
                break
        if report["pages"].get("Settings", {}).get("inspection", {}).get("overlayVisible"):
            path = "LocalPlayer.PlayerGui.ChestRPGUI.MenuOverlay.Frame.CloseMenu"
            report["closeAction"] = click(client, sid, path)
            time.sleep(.3)
            report["closed"] = run(client, sid, INSPECT)
        report["console"] = client.tool("get_console_output", {"studio_id": sid}, timeout=50)[-7500:]
        print("CONSOLE", report["console"], flush=True)
    finally:
        if sid and started:
            try:
                print("PLAY_STOP", client.tool("start_stop_play", {"studio_id": sid, "is_start": False}, timeout=95), flush=True)
            except Exception as error:
                print("PLAY_STOP_ERROR", str(error), flush=True)
        (OUT / "report.json").write_text(json.dumps(report, indent=2))
        print("REPORT", OUT / "report.json", flush=True)
        client.close()


if __name__ == "__main__":
    main()
