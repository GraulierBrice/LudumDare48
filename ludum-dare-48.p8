pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

function _init()
	physics_start(1/30)
    --rigidbody(60, 96, 8, 0, 0.5, 0.5, nil, 10)
	init_bullets(256)
	add(enemies, spawn_bat())
	spawn_player()
end

function _update()
    cls()
	update_player()
	update_enemies()
	update_bullets()
	physics_update()
end

function _draw()
	map(0,0)
	for i=1,#colliders do
		col_draw(colliders[i])
	end
	draw_bullets()
	draw_enemies()
	--print(enemies[1].hp,0,0,7)
	light()
end

function light()

end

-->8
--player

function spawn_player()
	player=rigidbody(64, 64, 2, 0.5, 4, 0.4, nil, 10)
	player.firerate=0.20
	player.nextshoot=0
	player.knockback=0.30
	player.flag=0
	player.shoot=machine_gun
	player.switch=2
	player.weapons={
		shot_gun={
			func=shot_gun,
			knockback=-128,
			firerate=0.25
		},
		machine_gun={
			func=machine_gun,
			knockback=-32,
			firerate=0.05
		}
	}
	player.weapon=player.weapons.machine_gun
end

function update_player()
	player.acc.y=64
	if time()>player.nextshoot then
		if btn(0) or btn(1) or btn(2) or btn(3) then
			local dir = vector(0,0)
			if btn(0) 	  then dir = vec_add(dir, vector(-1,0))
			elseif btn(1) then dir = vec_add(dir, vector(1,0))
			elseif btn(2) then dir = vec_add(dir, vector(0,-1))
			elseif btn(3) then dir = vec_add(dir, vector(0,1)) end
			player.weapon.func(dir)
			player.nextshoot = time() + player.weapon.firerate
			dir = vec_mul(dir, vector(player.weapon.knockback, player.weapon.knockback))
			player.vel = vec_add(player.vel, dir)
		end
	end
	if btnp(5) then
		player.firerate=1-player.firerate
		player.knockback=1-player.knockback
		player.weapon = (player.weapon==player.weapons.machine_gun) and player.weapons.shot_gun or player.weapons.machine_gun
		player.switch = time() + 1
	end
end

function bullet_hit(b, rb)
	if b.flag != rb.flag then
		b.lifetime=0
		rb.hp -= b.dmg
		if rb.hp <= 0 then
			del(rigidbodies, rb)
			del(colliders, rb)
			if rb == player then _init() else del(enemies, rb) end
		end
	end
end

-->8
-- bullets
function init_bullets(n)
	bullets={}
	for i=1,n do
		add(bullets, {pos=vector(0,0), move=nil, color=0, flag=0, lifetime=0, dmg=0})
	end
	bullets.first=1
end

function bullet_straight(pos, vel, color, flag, dmg)
	local b = bullet(pos, color, flag, dmg)
	b.vel=vector(vel.x, vel.y)
	b.move=bullet_straight_move
	return b
end

function bullet_straight_move(b)
	b.pos = vec_add(b.pos, vec_mul(b.vel, vector(phy.dt, phy.dt)))
end

function bullet(pos, color, flag, dmg)
	local b = bullets[bullets.first]
	b.pos=vector(pos.x, pos.y)
	b.color=color
	b.flag=flag
	b.dmg=dmg
	b.lifetime=5
	for i=bullets.first+1, #bullets+bullets.first do
		if i>#bullets then i=i-#bullets end
		if bullets[i].lifetime <= 0 then
			bullets.first=i
			break
		end
	end
	return b
end

function update_bullets()
	for i=1,#bullets do
		if bullets[i].lifetime>0 then
			bullets[i].lifetime = bullets[i].lifetime - phy.dt
			if bullets[i].move then
				bullets[i].move(bullets[i])
				for j=1,#rigidbodies do
					if col_overlap_point(rigidbodies[j], bullets[i].pos) then
						bullet_hit(bullets[i], rigidbodies[j])
						break
					end
				end
			end
		end
	end
end

function draw_bullets()
	for i=1,#bullets do
		if bullets[i].lifetime>0 then
			pset(bullets[i].pos.x, bullets[i].pos.y, bullets[i].color)
		end
	end
end

function machine_gun(dir)
	local bspeed=vector(64,64)
	bullet_straight(vec_add(player.pos, vector(player.radius*2*dir.y,player.radius*2*dir.x)), vec_mul(dir, bspeed), 7, 0, 3)
	bullet_straight(vec_add(player.pos, vector(-player.radius*2*dir.y,-player.radius*2*dir.x)), vec_mul(dir, bspeed), 7, 0, 3)
end

function shot_gun(dir)
	local bspeed=vector(128,128)
	local n=8
	for i=1,8 do
		bullet_straight(vec_add(player.pos, vec_mul(dir, vector(player.radius,player.radius))), vec_mul(vec_norm(vec_add(dir, vector(((i-n/2)/n)*dir.y,((i-n/2)/n)*dir.x))),bspeed), 7, 0, 8)
	end
end

-->8
-- enemies

enemies = {}

function spawn_bat()
	local bat= rigidbody(rnd()*128, 128, 3, 0.5, 4, 0.4, nil, 100)
	bat.sprites = {0,0,0,1,1,1}
	bat.flag = 1
	bat.frame = 0
	bat.reshoot = time()
	bat.update = function()
		bat.vel.y = 10*(player.pos.y - bat.pos.y) / abs(bat.pos.y - player.pos.y)
		if(time() > bat.reshoot) then 
			bullet_straight(bat.pos, vec_mul(vec_norm(vec_sub(player.pos, bat.pos)), vector(32,32)), 8, 1, 1) 
			bat.reshoot = time()+2
		end 
		bat.frame = (bat.frame + 1) % 6
	end
	bat.draw = function()
		spr(bat.sprites[bat.frame+1], bat.pos.x-3, bat.pos.y-4)
	end
	return bat
end

function spawn_spider()
	local spider= rigidbody(30,30, 5, 0.5, 4, 0.4, nil, 30)
	spider.sprites = {0,1}
	spider.flag = 1
	spider.reshoot = time()
	spider.update = function()
		if(time() > spider.reshoot) then
		local n = 24
			for i=1,n do
				bullet_straight(spider.pos, vec_mul(vector(cos(i/n),sin(i/n)),vector(32,32)), 8, 1, 1)
			end
		spider.reshoot = time() + 5
		end
	end
	spider.draw = function ()
		
	end
	return spider
end


function update_enemies()
	for i=1,#enemies do
		enemies[i].update()
		rb_update(enemies[i])
	end
end

function draw_enemies()
	for e in all(enemies) do
		e.draw()
	end
end


-->8
-- physics

function physics_start(dt, friction, bounce)
	colliders={}
	rigidbodies={}
    phy={
        dt=dt,
        friction=friction,
        bounce=bounce
    }
end

function physics_update()
	for i=1, #rigidbodies do
		rb_update(rigidbodies[i])
	end
end

function rigidbody(x, y, r, friction, drag, bounce, on_hit, hp)
	local rb = collider(x, y, r, false, on_hit)
	rb.acc = vector(0, 0)
	rb.vel = vector(0, 0)
    rb.friction = friction
    rb.drag = drag
    rb.bounce = bounce
	rb.hp = hp
	add(rigidbodies, rb)
	return rb
end

function collider(x, y, r, trg, on_hit, ign)
	local c = transform(x, y)
	c.radius = r
	c.trg = trg
	c.on_hit = on_hit
	if (not ign) then
		add(colliders, c)
	end
	return c
end

function rb_col_response(rb, col, data)
	local hit = col_overlap_col(data.new_col, col)
	if (hit) then
		local rel_vel
		if (col.vel) then rel_vel = vec_sub(col.vel, rb.vel)
		else rel_vel = vec_sub(vector(0,0), rb.vel) end
		if (rb.on_hit != nil) then
			rb.on_hit(rb, col, rel_vel)
		end
		if (col.on_hit != nil) then
			col.on_hit(col, rb, rel_vel)
		end
		if (not col.trg) then
			local norm = col_normal(data.new_col, hit)
			local dv = vec_dot(data.new_vel, norm) * (1 + rb.bounce)
			local delta_v = vec_mul(vector(-dv,-dv),norm)
			data.new_vel = vec_add(data.new_vel, delta_v)
			
			data.new_pos = vec_add(rb.pos, vec_mul(data.new_vel, vector(phy.dt, phy.dt)))
			data.new_col.pos = data.new_pos
		end
	end
	return data
end

function rb_update(rb)
	local new_acc = vec_sub(rb.acc, vec_mul(rb.vel, vector(rb.drag, rb.drag)))
	
	local new_vel = vec_add(rb.vel, vec_mul(new_acc, vector(phy.dt, phy.dt)))
	local new_pos = vec_add(rb.pos, vec_mul(new_vel, vector(phy.dt, phy.dt)))

	local new_col = collider(new_pos.x, new_pos.y, rb.radius, false, rb.on_hit, true)
	
	local data = {new_col=new_col, new_vel=new_vel, new_pos=new_pos}
	
	for i=1, #colliders do
		local col = colliders[i]
		if (col != rb) then
			if (abs(col.pos.x-rb.pos.x)<16 and abs(col.pos.y-rb.pos.y)<16) then
				data=rb_col_response(rb, col, data)
			end
		end
	end
	rb.acc = vector(0,0)
	rb.vel = data.new_vel
	rb.pos = data.new_pos

	if rb.pos.x > 128 - rb.radius then
		rb.vel.x = abs(rb.vel.x) * -rb.bounce * (rb.pos.x - 128 + rb.radius)
	elseif rb.pos.x < 0 + rb.radius then
		rb.vel.x = abs(rb.vel.x) * rb.bounce * -(rb.pos.x-rb.radius)
	end
end

function col_overlap_point(c, p)
	local dist = vec_len(vec_sub(c.pos, p))
    return dist <= c.radius
end

function col_overlap_col(c1, c2)
    local offs=vec_sub(c2.pos, c1.pos)
    local dist=vec_len(offs)
    local dir=vec_norm(offs)
	dist -= c1.radius + c2.radius
    if dist <= 0 then
        return vec_add(c1.pos, vec_mul(dir, vector(c1.radius, c1.radius)))
    else
        return false
    end
end

function col_normal(c, p)
	local offs=vec_sub(p, c.pos)
    return vec_norm(offs)
end

function col_draw(c)
    circ(c.pos.x, c.pos.y, c.radius, 7)
end

-->8
-- maths
function vector(x, y)
	return {x=x, y=y}
end

function vec_add(u, v)
	return vector(u.x+v.x, u.y+v.y)
end

function vec_sub(u, v)
	return vector(u.x-v.x, u.y-v.y)
end

function vec_mul(u, v)
	return vector(u.x*v.x, u.y*v.y)
end

function vec_dot(u, v)
	return u.x*v.x + u.y*v.y
end

function vec_len(v)
	return sqrt(vec_dot(v, v))
end

function vec_norm(v)
	if (v != vector(0,0)) then
		local d = 1/vec_len(v)
		return vec_mul(v, vector(d, d))
	else
		return v
	end
end

function transform(x, y)
	return {pos=vector(x, y)}
end

function tr_point(t, p)
	return vec_sub(p, t.pos)
end

function inv_tr_point(t, p)
	return vec_add(p, t.pos)
end
__gfx__
00000000110000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01000010111001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11100111dd1001dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d1111d10d1001d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d011210d001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111100001121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000001111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
