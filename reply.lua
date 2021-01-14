-- incredible-gmod.ru

local discordia = require("discordia")
local pathjoin = require("pathjoin")
local fs = require("fs")
local type = require("./type")

local insert, remove, concat, format = table.insert, table.remove, table.concat, string.format
local splitPath = pathjoin.splitPath
local readFileSync = fs.readFileSync
local Message = discordia.class.classes.Message
local TextChannel = discordia.class.classes.TextChannel

Message._OldReply = Message.__OldReply or Message.reply
TextChannel._OldSend = TextChannel._OldSend or TextChannel.send

function Message:reply(content, noreply)
	if noreply then
		return self._parent:send(content)
	else
		content = istable(content) and content or {content = content}
		content.message_reference = {
			guild_id = self._parent.guild and self._parent.guild.id or nil,
			channel_id = self._parent.id,
			message_id = self.id,
		}

		return self._parent:send(content)
	end
end

local function parseFile(obj, files)
	if type(obj) == 'string' then
		local data, err = readFileSync(obj)
		if not data then
			return nil, err
		end
		files = files or {}
		insert(files, {remove(splitPath(obj)), data})
	elseif type(obj) == 'table' and type(obj[1]) == 'string' and type(obj[2]) == 'string' then
		files = files or {}
		insert(files, obj)
	else
		return nil, 'Invalid file object: ' .. tostring(obj)
	end
	return files
end

function TextChannel:send(content)
	local data, err

	if type.istable(content) then
		local tbl = content
		content = tbl.content

		if type.isstring(tbl.code) then
			content = format('```%s\n%s\n```', tbl.code, content)
		elseif tbl.code == true then
			content = format('```\n%s\n```', content)
		end

		local mentions
		if tbl.mention then
			mentions, err = parseMention(tbl.mention)
			if err then
				return nil, err
			end
		end
		if type.istable(tbl.mentions) then
			for _, mention in ipairs(tbl.mentions) do
				mentions, err = parseMention(mention, mentions)
				if err then
					return nil, err
				end
			end
		end
		if mentions then
			insert(mentions, content)
			content = concat(mentions, " ")
		end

		local files
		if tbl.file then
			files, err = parseFile(tbl.file)
			if err then
				return nil, err
			end
		end
		if type.istable(tbl.files) then
			for _, file in ipairs(tbl.files) do
				files, err = parseFile(file, files)
				if err then
					return nil, err
				end
			end
		end

		data, err = self.client._api:createMessage(self._id, {
			content = content,
			tts = tbl.tts,
			nonce = tbl.nonce,
			embed = tbl.embed,
			message_reference = tbl.message_reference and tbl.message_reference or nil,
		}, files)

	else
		data, err = self.client._api:createMessage(self._id, {content = content})
	end

	if data then
		return self._messages:_insert(data)
	else
		return nil, err
	end

end

discordia.class.classes.GuildTextChannel.send = TextChannel.send -- discordia class lib sucks when base classes come into play
