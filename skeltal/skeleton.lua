--[[
Skeltal: a programmatic skeleton creation library designed for LOVE2D

Copyright 2018 Brian Sarfati

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local _PACKAGE = (...):match("^(.+)[%./][^%./]+") or ""

local skeleton_mt = {}
skeleton_mt.__index = function(t,k)
  if rawget(skeleton_mt,k) then return rawget(skeleton_mt,k) end
  if t.root[k] then return t.root[k] end
  return nil
end

skeleton_mt.ROOT_LAYER = 0

local Vector = require(_PACKAGE .. "/dep/brinevector")
local Bone = require(_PACKAGE .. "/bone")

function skeleton_mt:new(x,y)  
  -- required to host root bone
  self.pos = Vector(x or 0, y or 0)
  self.origin = Vector(0,0)
  self.rot = 0
  self.scale = 1
  self.skeleton = self
  self.name = "skeleton"
  self.template = type(x) == "boolean" and x or false
  -- properties
  self.flipped = false
  self.minlayer = skeleton_mt.ROOT_LAYER
  self.maxlayer = skeleton_mt.ROOT_LAYER
  -- layer reference table
  self.layers = {}
  -- create root
  self.root = Bone.newBone(self,{
    name = "root",
    origin = Vector(0,0),
    connect = Vector(0,0),
    loose = false,
    rot = 0,
    layer = skeleton_mt.ROOT_LAYER
  })
  
end


function skeleton_mt:setPos(x,y)
  self.pos = Vector(x,y)
end

function skeleton_mt:rotate(angle)
  self.rot = self.rot + angle
end

function skeleton_mt:rotateTo(angle)
  self.rot = angle
end  

function skeleton_mt:flip()
  self.flipped = not self.flipped
end

local layer_mt = {__mode = "v"}  -- weak table for layer reference

function skeleton_mt:addToLayer(bone,layer)
  if self.layers[layer] then
    self:__insertToLayer(bone,layer)
    return
  end
  self.layers[layer] = setmetatable({},layer_mt)
  
  self:__insertToLayer(bone,layer)
  
  if layer > self.maxlayer then self.maxlayer = layer end
  if layer < self.minlayer then self.minlayer = layer end
end

function skeleton_mt:__insertToLayer(bone,layer)
  local layerlist = self.layers[layer]
  for i = 1, #layerlist + 1 do
    if layerlist[i] == nil then 
      layerlist[i] = bone
      break
    end 
  end
end

function skeleton_mt:__cleanLayers(bone)
  -- manually goes through all the layers and scrubs the bone and its children from it
  for i = self.minlayer, self.maxlayer do
    local layer = self.layers[i]
    if layer then
      for i,v in pairs(layer) do
        if (v == bone) or v:isChildOf(bone) then
          layer[i] = nil
        end
      end
    end
  end
end
  
function skeleton_mt:update(dt) 
  self.root:update(dt)
end

function skeleton_mt:draw()
  for i = self.minlayer, self.maxlayer do
    local layer = self.layers[i]
    if layer then
      for _,bone in pairs(layer) do
        bone:draw()
      end
    end
  end
end

function skeleton_mt:drawDebug()
  self.root:drawDebug()
  love.graphics.setColor(255,255,255,255)
end

local function iter_printbonetree(result,bone,tabs)
  for i = 1,tabs do
    result.out = result.out .. "\t"
  end
  result.out = result.out .. bone.name .. "\n"
  for _,child in pairs(bone.children) do
    iter_printbonetree(result,child,tabs+1)
  end
end

function skeleton_mt:printBoneTree()
  local result = {out = ""}
  iter_printbonetree(result,self.root,0)
  return result.out
end

local function iter_clone(child, dest_parent, keep_template)
  -- make a new copy
  local childcopy = child:__duplicate(keep_template)
  -- link the copy parent and the copy child together
  childcopy.parent = dest_parent                    -- @hack have to manually make some tables
  childcopy.skeleton = dest_parent.skeleton
  childcopy.skeleton:addToLayer(childcopy,childcopy.layer)
  childcopy.children = {}
  dest_parent.children[childcopy.name] = childcopy
  for _,grandchild in pairs(child.children) do
    iter_clone(grandchild, childcopy, keep_template)
  end
end

function skeleton_mt:clone(x,y,keep_template)
  local clone = skeleton_mt.newSkeleton(x,y)
  for _,b in pairs(self.root.children) do
    iter_clone(b, clone.root, keep_template)
  end
  return clone
end

function skeleton_mt.newSkeleton(...)
  -- creates a new skeleton
  local skel = setmetatable({},skeleton_mt)
  skel:new(...)
  return skel
end


return skeleton_mt