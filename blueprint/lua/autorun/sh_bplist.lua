AddCSLuaFile()

module("bplist", package.seeall)

bpcommon.CallbackList({
	"ADD",
	"REMOVE",
	"CLEAR",
	"RENAME",
})

local meta = {}
meta.__index = meta

function meta:Init(...)

	bpcommon.MakeObservable(self)
	return self:Clear()

end

function meta:NamedItems( prefix )

	self.namedItems = true
	self.namePrefix = (prefix or "Item") .. "_"
	return self

end

function meta:Clear()

	self.items = {}
	self.itemLookup = {}
	self.nextID = 1
	self:FireListeners(CB_CLEAR)
	return self

end

function meta:Advance()
	self.nextID = self.nextID + 1
end

function meta:NextIndex()
	return self.nextID
end

function meta:Items( reverse )

	local items = self.items

	if reverse then
		local i = #items + 1
		return function() 
			i = i - 1
			if i > 0 then return items[i].id, items[i] end
		end
	else
		local i, n = 0, #items
		return function()
			if #items ~= n then error("Concurrent modification of list!") end
			i = i + 1
			if i <= n then return items[i].id, items[i] end
		end
	end

end

function meta:ItemIDs( reverse )

	local items = self.items

	if reverse then
		local i = #items + 1
		return function() 
			i = i - 1
			if i > 0 then return items[i].id end
		end
	else
		local i, n = 0, #items
		return function() 
			if #items ~= n then error("Concurrent modification of list!") end
			i = i + 1
			if i <= n then return items[i].id end
		end
	end

end

function meta:Size()

	return #self.items

end

function meta:GetNameForItem( optName, item )

	optName = optName or item.name
	local name = bpcommon.Sanitize(optName) 
	if name == nil then name = self.namePrefix .. item.id end
	return bpcommon.Camelize(name)

end

function meta:Add( item, optName )

	if item.id ~= nil then error("Cannot add uniquely indexed items to multiple lists") end
	item.id = self:NextIndex()

	if self.namedItems then
		item.name = self:GetNameForItem( optName, item )
	end

	table.insert( self.items, item )
	self.itemLookup[item.id] = item
	self:Advance()

	self:FireListeners(CB_ADD, item.id, item)

	return item.id, item

end

function meta:Remove( id )

	return self:RemoveIf( function(x) return x.id == id end )

end

function meta:RemoveIf( cond )

	local removed = 0
	local items = self.items
	for i=#items, 1, -1 do

		local item = items[i]
		if cond( item ) then

			table.remove( items, i ) 
			self:FireListeners(CB_REMOVE, item.id, item)
			self.itemLookup[item.id] = nil
			item.id = nil
			removed = removed + 1

		end

	end

	return removed

end

function meta:Rename( id, newName )

	local item = self:Get(id)
	if item == nil then return false end

	local prev = item.name
	item.name = self:GetNameForItem( newName, item )
	self:FireListeners(CB_RENAME, item.id, prev, item.name)

end

function meta:Get( id )

	return self.itemLookup[id]

end

function meta:GetTable()

	return self.items

end

function New()

	return setmetatable({}, meta):Init()

end