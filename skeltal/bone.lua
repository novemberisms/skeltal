--[[
Skeltal: a programmatic skeleton creation library designed for LOVE2D

Copyright 2018 Brian Sarfati

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local _PACKAGE = (...):match("^(.+)[%./][^%./]+") or ""

local bone_mt = {}
bone_mt.__index = function(t,k)
  if rawget(bone_mt,k) then return rawget(bone_mt,k) end
  if rawget(t.children,k) then return rawget(t.children,k) end
  return nil
end

local Vector = require (_PACKAGE .. "/dep/brinevector")

function bone_mt:addBone(args)
  -- args must be a table with the following fields. only 'name' is required
  --[[
  name      (REQ.)    the name of the bone. must be unique per skeleton!
  image     (nil)     the image to draw, if any. Drawn before the drawfxn
  quad      (nil)     the quad to use when drawing the image, if any.
  drawfxn   (nil)     the function to call upon drawing, if any. useful for animated sprites
  originx   (0)       the x position for the base of the bone. it rotates about this point
  originy   (0)       the y position for the base of the bone. it rotates about this point
  connectx  (0)       the x position of the spot on the parent image the bone will connect to
  connecty  (0)       the y position of the spot on the parent image the bone will connect to
  loose     (false)   whether the joint connecting this bone to its parent transfers rotation
  rot       (0)       starting rotation
  rotvel    (0)       starting rotational velocity in radians per second
  layer     ("above") either "above" or "below" or a number
  template  (*)       set to 'true' to enable copying this bone. 
  vars**    (nil)     a table you can use to add other vars to the bone for use in updatefxn or drawfxn
                        
    
  *defaults to whatever parent's value is
  **WARNING. table values in vars are copied by reference, 
    so editing once will edit that table in the vars of all bones copied from this bone
  --]]
  assert(not self.children[args.name], 
    "bone '" .. self.name .. "' already has a child named '" .. args.name .. "'")
  local bone = bone_mt.newBone(self,args)
  self.children[args.name] = bone
  return bone
end

function bone_mt.newBone(parent,args)
  local bone = setmetatable({},bone_mt)
  bone:new(parent,args)
  return bone
end

function bone_mt:new(parent,args)
  
  self.parent = parent        -- @clone manual create
  self.name = args.name
  self.image = args.image
  self.quad = args.quad
  self.updatefxn = args.updatefxn
  self.drawfxn = args.drawfxn
  self.origin = args.origin or Vector(args.originx or 0, args.originy or 0)
  self.offset = (args.connect or Vector(args.connectx or 0, args.connecty or 0)) 
                - self.parent.origin
  self.loose = args.loose or false
  self.rotvel = args.rotvel or 0
  if type(args.layer) == "number" then
    self.layer = args.layer
  elseif args.layer == "below" then
    self.layer = self.parent.layer - 1
  else
    self.layer = self.parent.layer + 1
  end
  self.rot_offset = args.rot or 0
  self.rot = 0
  
  self.vars = args.vars -- @clone exception to tables
  
  self.template = args.template-- or false
  if args.template == nil then self.template = self.parent.template end
 
  if self.template then
    self.constructor_args = args
  end
  
  self.initial_rotation = self.rot_offset -- can be used as a reference
  self.skeleton = self.parent.skeleton      -- @clone manual create
  self.skeleton:addToLayer(self,self.layer) -- @clone manual create
  self.children = {}                        -- @clone manual create
  
  self:updatePosRot()
end

function bone_mt:update(dt) 
  if self.updatefxn then self.updatefxn(self,dt) end
  
  self.rot_offset = self.rot_offset + self.rotvel * dt
  
  if self.rot_offset > math.pi then 
    self.rot_offset = self.rot_offset - 2*math.pi 
  elseif self.rot_offset < -math.pi then
    self.rot_offset = self.rot_offset + 2*math.pi
  end
 
  self:updatePosRot()
 
  for _,bone in pairs(self.children) do
    bone:update(dt)
  end
end

function bone_mt:updatePosRot()
  if self.loose then
    self.rot = self.rot_offset
  else
    self.rot = self.parent.rot + self.rot_offset
  end
  
  local angled_offset = 
    self.offset:angled(self.offset.angle + self.parent.rot)*self.skeleton.scale
  
  if self.skeleton.flipped then angled_offset.x = -angled_offset.x end

  self.pos = self.parent.pos + angled_offset
end

function bone_mt:translate(x,y)
  if not y then
    self.offset = self.offset + x -- if only one argument, assume it is a vector
  else
    self.offset = self.offset + Vector(x,y)
  end
end

function bone_mt:absoluteTranslate(x,y)
  local abs_disp = Vector(x,y)
  local rx_base = Vector(1,0):angled(self.parent.rot)
  local ry_base = Vector(1,0):angled(self.parent.rot + math.pi/2)
  self:translate(abs_disp * rx_base, abs_disp * ry_base)
end

function bone_mt:setRotVel(vel)
  self.rotvel = vel
end

function bone_mt:rotate(angle)  
  -- note that if bone has `rotvel`, then this will apply _in addition_ to `rotvel`
  self.rot_offset = self.rot_offset + angle
end

function bone_mt:rotateTo(angle)
  self.rot_offset = angle
end

function bone_mt:relativeRotateTo(angle)
  self.rot_offset = self.initial_rotation + angle
end

function bone_mt:getApparentRotation()
  return self.skeleton.flipped and math.pi - self.rot or self.rot
end

function bone_mt:draw()
  if self.image then
    local rot = self.skeleton.flipped and -self.rot or self.rot
    local scalex = self.skeleton.flipped and -self.skeleton.scale or self.skeleton.scale
    if self.quad then
      love.graphics.draw(
        self.image,
        self.quad,
        self.pos.x, self.pos.y,
        rot,
        scalex,self.skeleton.scale,
        self.origin.x,self.origin.y
      )
    else
      love.graphics.draw(
        self.image,
        self.pos.x, self.pos.y,
        rot,
        scalex,self.skeleton.scale,
        self.origin.x,self.origin.y
      )
    end
  end
  if self.drawfxn then 
    -- if a custom draw function is given, rather than getting all these arguments,
    -- most of the time you can use (...) and plug it into a drawing function
    -- like in anim8, just use
    --    function(self,...) self.animation:draw(self.spritesheet,...) end
    self:drawfxn(
      self.pos.x,
      self.pos.y,
      self.skeleton.flipped and -self.rot or self.rot,
      self.skeleton.flipped and -self.skeleton.scale or self.skeleton.scale,
      self.skeleton.scale,
      self.origin.x,
      self.origin.y
    ) 
  end
end

function bone_mt:drawDebug()
  love.graphics.setColor(255,0,0,255)
  love.graphics.circle("fill",self.pos.x,self.pos.y,5)
  love.graphics.setColor(0,0,255,255)
  local parent = self.parent.pos
  local me = self.pos
  love.graphics.line(parent.x,parent.y,me.x,me.y)
  love.graphics.setColor(255,0,255,255)
  
  local rot = self.pos + Vector(50,0):angled(self.rot)
  love.graphics.line(me.x,me.y,rot.x,rot.y)
  
  for _,bone in pairs(self.children) do
    bone:drawDebug()
  end
end

function bone_mt:delete(collect_immediately)
  for name, bone in pairs(self.parent.children) do
    if bone == self then
      self.parent.children[name] = nil
      print("deleted bone",name)
      break
    end
  end
  if collect_immediately then 
    self.skeleton:__cleanLayers(self)
  end
end

function bone_mt:isChildOf(bone)
  local parent = self.parent
  while parent.name ~= "skeleton" do
    if parent == bone then return true end
    parent = parent.parent
  end
  return false
end

function bone_mt:addTemplate(args)
  -- args is a table with a 'source' and a 'name' field, as well as any properties
  -- in the new bone that must be different from the old one
  
  -- get the bone being cloned
  local template = args.source
  assert( -- must be a template
    template.template,
    "cannot copy bone " .. template.name .. " unless 'template' is true"
  )
  -- get the constructing table for the bone and copy it
  local oldconstruct = template.constructor_args
  local newconstruct = {}
  for k,v in pairs(oldconstruct) do
    newconstruct[k] = v
  end
  -- overwrite the constructing table for any keys in args
  -- most notably, 'name'
  for k,v in pairs(args) do
    newconstruct[k] = v
  end
  -- remove the "source" field because it will maintain a reference to a bone and can cause
  -- memory leaks
  newconstruct.source = nil
  
  -- copy the source itself with modified constructing args
  local copy_base = self:addBone(newconstruct)
  -- temporarily disable copying of the new bone, for if the source is an ancestor of
  -- the new bone to add, and there is an unbroken chain of templates between them,
  -- it will lead to an infinite loop of copying over and over. interesting stuff
  local old_copy_base_template_value = copy_base.template
  copy_base.template = false
  -- recursively copy all children of the source that have 'template' set to true
  for _,bone in pairs(template.children) do
    bone:__copyTo(copy_base)
  end
  -- reset the template parameter of the copy
  copy_base.template = old_copy_base_template_value
  
  return copy_base
end

function bone_mt:__copyTo(copy) -- i guess you could use this function on its own,
                                -- but you can't specify any differences in the construct args
  if not self.template then return end
  -- copy self to copy
  local childcopy = copy:addBone(self.constructor_args)
  for _,bone in pairs(self.children) do
    bone:__copyTo(childcopy)
  end
end

function bone_mt:__duplicate(keep_template)
  local copy = setmetatable({},bone_mt)
  
  for k,v in pairs(self) do
    if (not keep_template) and (k == "template") then
      copy.template = false
    elseif keep_template and (k == "constructor_args") then
      copy.constructor_args = v
    elseif k == "vars" then
      copy.vars = {}
      for varkey, varval in pairs(v) do
        copy.vars[varkey] = varval
      end
    elseif type(v) == "table" then
      copy[k] = nil
    elseif Vector.isVector(v) then
      copy[k] = Vector(v.x,v.y)
    else
      copy[k] = v
    end
  end
  
  return copy
end

return bone_mt
