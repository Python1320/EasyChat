local EASYCHAT_DM        = "EASY_CHAT_MODULE_DM"
local EASYCHAT_DM_REMOVE = "EASY_CHAT_MODULE_DM_REMOVE"

if SERVER then
    util.AddNetworkString(EASYCHAT_DM)
    util.AddNetworkString(EASYCHAT_DM_REMOVE)

    net.Receive(EASYCHAT_DM,function(_,ply)
        local target = net.ReadEntity()
        local message = net.ReadString()
        if not IsValid(target) or message:Trim() == "" then return end

        net.Start(EASYCHAT_DM)
        net.WriteEntity(ply)
        net.WriteString(message)
        net.Send(target)
    end)

    hook.Add("PlayerDisconnected","EasyChatModuleDMTab",function(ply)
        net.Start(EASYCHAT_DM_REMOVE)
        net.WriteEntity(ply)
        net.Broadcast()
    end)
end

if CLIENT then
    local DM_TAB = {
        Chats = {},
        ActiveChat = {
            Player = NULL,
            RichText = NULL,
            Name = "",
            NewMessages = 0,
            Line = NULL,
        },
        Init = function(self)
            local frame = self

            self.DMList = self:Add("DListView")
            self.DMList:SetWide(100)
            self.DMList:Dock(LEFT)
            self.DMList:AddColumn("Chats")
            self.DMList.OnRowSelected = function(self,index,row)
                local ply = row.Player
                if IsValid(ply) then
                    if IsValid(frame.ActiveChat.RichText) then
                        frame.ActiveChat.RichText:Hide()
                    end
                    local chat = frame.Chats[ply]
                    chat.RichText:Show()
                    chat.NewMessages = 0
                    frame.ActiveChat = chat
                else
                    self:RemoveLine(index)
                end
            end

            self.TextEntry = self:Add("DTextEntry")
            self.TextEntry:SetTall(20)
            self.TextEntry:Dock(BOTTOM)
            self.TextEntry:SetHistoryEnabled(true)
            self.TextEntry.HistoryPos = 0
            self.TextEntry:SetUpdateOnType(true)

            local lastkey = KEY_ENTER
            self.TextEntry.OnKeyCodeTyped = function(self,code)
                EasyChat.SetupHistory(self,code)
                EasyChat.UseRegisteredShortcuts(self,lastkey,code)

                if code == KEY_ESCAPE then
                    chat.Close()
                    gui.HideGameUI()
                elseif code == KEY_ENTER or code == KEY_PAD_ENTER then
                    self:SetText(string.Replace(self:GetText(),"╚​",""))
                    if string.Trim(self:GetText()) ~= "" then
                        frame:SendMessage(string.sub(self:GetText(),1,3000))
                    end
                end

                lastkey = code
            end

            if not EasyChat.UseDermaSkin then
                self.DMList.Paint = function(self,w,h)
                    surface.SetDrawColor(EasyChat.OutlayColor)
                    surface.DrawRect(0, 0, w,h)
                    surface.SetDrawColor(EasyChat.OutlayOutlineColor)
                    surface.DrawOutlinedRect(0, 0, w,h)
                end

                local header = self.DMList.Columns[1].Header
                header:SetTextColor(Color(255,255,255))
                header.Paint = function(self,w,h)
                    surface.SetDrawColor(EasyChat.OutlayColor)
                    surface.DrawRect(0, 0, w,h)
                    surface.SetDrawColor(EasyChat.OutlayOutlineColor)
                    surface.DrawOutlinedRect(0, 0, w,h)
                end
            end
        end,
        CreateChat = function(self,ply)
            if not IsValid(ply) then return end
            if self.Chats[ply] then return end

            local richtext = self:Add("RichText")
            if not EasyChat.UseDermaSkin then
                richtext:InsertColorChange(255,255,255,255)
            end
            richtext.PerformLayout = function(self)
                self:SetFontInternal("EasyChatFont")
                if not EasyChat.UseDermaSkin then
                    self:SetFGColor(EasyChat.TextColor)
                end
            end
            richtext.ActionSignal = function(self,name,value)
                if name == "TextClicked" then
                    EasyChat.OpenURL(value)
                end
            end
            richtext:Dock(FILL)
            richtext:Hide()

            local chat = {
                Player = ply,
                Name = ply:Nick(),
                RichText = richtext,
                NewMessages = 0,
            }

            local line = self.DMList:AddLine(chat.Name)
            if not EasyChat.UseDermaSkin then
                line.Columns[1]:SetTextColor(Color(255,255,255))
            end
            line.Player = ply
            chat.Line = line

            self.Chats[ply] = chat

            if not IsValid(self.ActiveChat.Player) then
                self.ActiveChat = chat
            end

            return chat
        end,
        RemoveChat = function(self,ply)
            if not IsValid(ply) then return end
            if not self.Chats[ply] then return end

            local chat = self.Chats[ply]
            chat.RichText:Remove()
            self.Chats[ply] = nil

            self.DMList:Clear()
            for _,chat in pairs(self.Chats) do
                local line = self.DMList:AddLine(chat.Player:Nick())
                chat.Line = line
                line.Player = chat.Player
            end
        end,
        SendMessage = function(self,message)
            local i = self.DMList:GetSelectedLine()
            local line = self.DMList:GetLine(i)
            if not line then
                self.TextEntry:SetText("")
                return
            end

            local ply = line.Player
            if IsValid(ply) then
                local chat = self.Chats[ply]
                self:AddText(chat.RichText,LocalPlayer(),": " .. message)
                net.Start(EASYCHAT_DM)
                net.WriteEntity(chat.Player)
                net.WriteString(message)
                net.SendToServer()
            else
                self:AddText(chat.RichText,"The player you are trying to message is not on the server anymore!")
            end

            self.TextEntry:SetText("")
        end,
        AddText = function(self,richtext,...)
            richtext:AppendText("\n")
            local args = { ... }
            for _,arg in ipairs(args) do
                if type(arg) == "string" then
                    if not EasyChat.UseDermaSkin then
                        richtext:InsertColorChange(255,255,255,255)
                    end
                    if EasyChat.IsURL(arg) then
                        local words = string.Explode(" ",arg)
                        for k,v in ipairs(words) do
                            if k > 1 then
                                richtext:AppendText(" ")
                            end
                            if EasyChat.IsURL(v) then
                                local url = string.gsub(v,"^%s:","")
                                richtext:InsertClickableTextStart(url)
                                richtext:AppendText(url)
                                richtext:InsertClickableTextEnd()
                            else
                                richtext:AppendText(v)
                            end
                        end
                    else
                        richtext:AppendText(arg)
                    end
                elseif type(arg) == "Player" then
                    richtext:InsertColorChange(66,134,244,255)
                    richtext:AppendText(arg == LocalPlayer() and "me" or arg:Nick())
                end
            end
        end,
        Notify = function(self,chat,message)
            chat.NewMessages = chat.NewMessages + 1
            EasyChat.FlashTab("DM")
            _G.chat.AddText(Color(255,255,255),"[DM | ",Color(255,127,127),chat.Player,Color(255,255,255),"] " .. message)
        end,
        Think = function(self)
            for _,chat in pairs(self.Chats) do
                local line = chat.Line
                if not IsValid(chat.Player) then return end
                if chat.NewMessages > 0 then
                    line:SetColumnText(1,chat.Player:Nick() .. " (" .. chat.NewMessages .. ")")
                else
                    line:SetColumnText(1,chat.Player:Nick())
                end
            end
        end,
    }

    vgui.Register("ECDMTab",DM_TAB,"DPanel")
    local dmtab = vgui.Create("ECDMTab")

    net.Receive(EASYCHAT_DM,function()
        local sender = net.ReadEntity()
        local message = net.ReadString()
        if not IsValid(sender) then return end

        local chat = dmtab.Chats[sender]
        if not chat then
            chat = dmtab:CreateChat(sender)
        end
        dmtab:AddText(chat.RichText,sender,": " .. message)
        if not EasyChat.IsOpened() then
            dmtab:Notify(chat,message)
        else
            local activetabname = EasyChat.GetActiveTab().Tab.Name
            if (activetabname == "DM" and dmtab.ActiveChat ~= chat) or activetabname ~= "DM" then
                dmtab:Notify(chat,message)
            end
        end
    end)

    net.Receive(EASYCHAT_DM_REMOVE,function()
        local ply = net.ReadEntity()
        dmtab:RemoveChat(ply)
    end)

    hook.Add("ECTabChanged","EasyChatModuleDMTab",function(_,tab)
        if tab == "DM" then
            local chat = dmtab.ActiveChat
            if IsValid(chat.Player) and chat.NewMessages > 0 then
                chat.NewMessages = 0
            end
        end
    end)

    hook.Add("NetworkEntityCreated","EasyChatModuleDMTab",function(ent)
        if ent:IsPlayer() and ent ~= LocalPlayer() then
            dmtab:CreateChat(ent)
        end
    end)

    hook.Add("ECInitialized","EasyChatModuleDMTab",function()
        for _,ply in pairs(player.GetAll()) do
            if ply ~= LocalPlayer() then
                dmtab:CreateChat(ply)
            end
        end
    end)

    EasyChat.AddTab("DM",dmtab)
    EasyChat.SetFocusForOn("DM",dmtab.TextEntry)
end

return "Direct Messages"