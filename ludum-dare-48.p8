pico-8 cartridge // http://www.pico-8.com
version 32
__lua__

function _init()
	physics_start(1/60)
    --rigidbody(60, 96, 8, 0, 0.5, 0.5, nil, 10)
	init_bullets(256)
	spawn_player()
end

function _update60()
    cls()
	update_player()
	update_enemies()
	update_bullets()
	physics_update()
end

function _draw()
	local y=time()
	draw_environment(y)
	draw_bullets()
	draw_enemies()
	draw_player()
	draw_ui()
end

function draw_environment(z)
	local s = 16+z/10
	for i=0,15 do
		for j=0,15 do
			local a = vec_len(vector(i-7.5,j-7.5))/50
			spr(min(33, max(16, s+1-a)), i*8,j*8)
		end
	end
end

-->8
--player

function spawn_player()
	player=rigidbody(64, 64, 2, 0.5, 4, 0.4, function(rb) rb.hp-=10-5000/(time()+500) end , 1000)
	player.firerate=0.20
	player.nextshoot=0
	player.knockback=0.30
	player.flag=0
	player.shoot=machine_gun
	player.switch=2
	player.weapons={
		shot_gun={
			func=shot_gun,
			knockback=-96,
			firerate=0.25
		},
		machine_gun={
			func=machine_gun,
			knockback=-16,
			firerate=0.05
		}
	}
	player.weapon=player.weapons.machine_gun
end

function update_player()
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

function draw_player()
	local a = atan2(player.vel.x, player.vel.y)
	local f = (vec_len(player.vel)/4 + time()) % 2
	if a<0.125 or 0.875<a   then
		spr(7+f, player.pos.x-4,player.pos.y-4,1,1,true)
	elseif a<0.375 then
		spr(9+f, player.pos.x-4,player.pos.y-4)
	elseif a<0.625 then
		spr(7+f, player.pos.x-4,player.pos.y-4)
	else
		spr(9+f, player.pos.x-4,player.pos.y-4,1,1,false,true)
	end
end



function draw_ui()
	local ratio = player.hp/1000
	local width = max(1, 126*ratio)
	if width > 96 then color(11)
	elseif width > 64 then color(10)
	elseif width > 32 then color(9)
	else color(8) end
	rect(0,0, 127,5)
	rectfill(1,1,32, 4, 8)
	rectfill(33,1,64, 4, 9)
	rectfill(65,1,96, 4, 10)
	rectfill(97,1,126, 4, 11)
	if ratio < 1 then
		rectfill(width,1, 126, 4, 0)
	end
	rect(0,6,30,16,5)
	rectfill(1,7,29,15,4)
	spr(player.weapon.func == machine_gun and 12 or 11,1,7)
	color(7)
	print(flr(time()).."m",10,9)
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
				if bullets[i].pos.x > 0 and bullets[i].pos.x < 128 and bullets[i].pos.y > 0 and bullets[i].pos.y < 128 then
					for j=1,#rigidbodies do
						if col_overlap_point(rigidbodies[j], bullets[i].pos) then
							bullet_hit(bullets[i], rigidbodies[j])
							break
						end
					end
				else
					bullets[i].lifetime = 0
				end
			end
		end
	end
end

function draw_bullets()
	for i=1,#bullets do
		if bullets[i].lifetime>0 then
			circ(bullets[i].pos.x, bullets[i].pos.y, 1, bullets[i].color)
		end
	end
end

function machine_gun(dir)
	local bspeed=vector(64,64)
	bullet_straight(vec_add(player.pos, vector(player.radius*dir.y,player.radius*dir.x)), vec_mul(dir, bspeed), 7, 0, 30)
	bullet_straight(vec_add(player.pos, vector(-player.radius*dir.y,-player.radius*dir.x)), vec_mul(dir, bspeed), 7, 0, 30)
end

function shot_gun(dir)
	local bspeed=128
	local n=8
	for i=1,n do
		local s = (((rnd()-0.5) * 0.25) + 1) * bspeed
		s = vector(s,s)
		bullet_straight(vec_add(player.pos, vec_mul(dir, vector(player.radius,player.radius))), vec_mul(vec_norm(vec_add(dir, vector(((i-n/2)/n)*dir.y,((i-n/2)/n)*dir.x))), s), 7, 0, 80)
	end
end

-->8
-- enemies

enemies = {}

function spawn_bat()
	local bat= rigidbody(rnd()*120+4, 128, 3, 0.5, 4, 0.4, nil, 100-60000/(time()+600))
	bat.sprites = {0,0,0,0,0,1,1,1,1,1}
	bat.flag = 1
	bat.frame = 0
	bat.reshoot = time()
	bat.update = update_bat
	bat.draw = draw_bat
	return bat
end

function update_bat(bat)
	bat.vel.y = 10*(player.pos.y - bat.pos.y) / abs(bat.pos.y - player.pos.y)
	if(time() > bat.reshoot) then 
		if(time() > bat.reshoot) then 
	if(time() > bat.reshoot) then 
		bullet_straight(bat.pos, vec_mul(vec_norm(vec_sub(player.pos, bat.pos)), vector(64,64)), 8, 1, 30-1500/(time()+50))
		bat.reshoot = time()+1
	end 
		end 
	end 
	bat.frame = (bat.frame + 1) % 10
end

function draw_bat(bat)
	spr(bat.sprites[bat.frame+1], bat.pos.x-3, bat.pos.y-4)
end

function spawn_spider()
	local spider= rigidbody(rnd()*120+4,rnd()*120+4, 7, 0.5, 4, 0.4, nil, 300-60000/(time()+200))
	spider.sprites = {2,3,4,5}
	spider.flag = 1
	spider.reshoot = time()
	spider.update = update_spider
	spider.draw = draw_spider
	return spider
end

function update_spider(spider)
	if(time() > spider.reshoot) then
	local n = 24
		for i=1,n do
			bullet_straight(spider.pos, vec_mul(vector(cos(i/n),sin(i/n)),vector(64,64)), 8, 1, 50-2500/(time()+50))
		end
	spider.reshoot = time() + 3
	end
end

function draw_spider(spider)
	spr(spider.sprites[flr(rnd(0.51)*2+1)],spider.pos.x-8,spider.pos.y-8)
	spr(spider.sprites[flr(rnd(0.51)*2+1)],spider.pos.x,spider.pos.y-8, 1, 1, true)
	spr(spider.sprites[flr(rnd(0.51)*2+3)],spider.pos.x-8,spider.pos.y)
	spr(spider.sprites[flr(rnd(0.51)*2+3)],spider.pos.x,spider.pos.y, 1, 1, true)
end

function spawn_fish(x,y)
	local fish = rigidbody(x,y,3, 0.5, 4, 0.4, nil, 100-60000/(time()+600))
	fish.sprites={6,6,6}
	fish.flag = 1
	fish.frame = 0
	fish.update = update_fish
	fish.draw = draw_fish
	return fish
end

function update_fish(fish)
	fish.vel = vec_mul(vec_norm(vec_sub(player.pos, fish.pos)),vector(16,16))
end

function draw_fish(fish)
	spr(fish.sprites[fish.frame+1], fish.pos.x-3, fish.pos.y-4)
end


function update_enemies()
	for i=1,#enemies do
		enemies[i].update(enemies[i])
		rb_update(enemies[i])
	end
	if #enemies<10 then
		if rnd()<1/(1000-time()) then
			add(enemies,spawn_spider())
		elseif rnd()<1/(300-time()) then
			add(enemies, spawn_bat())
		elseif rnd()<1/(300-time()) then
			add(enemies, spawn_fish(0,rnd(128)))
		end
	end
end

function draw_enemies()
	for e in all(enemies) do
		e.draw(e)
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

	if (rb.pos.x > 127 - rb.radius) and (rb.vel.x > 0) or (rb.pos.x < rb.radius) and (rb.vel.x < 0) then
		rb.vel.x *= -2 +rb.bounce
	end

	if (rb.pos.y > 127 - rb.radius) and (rb.vel.y > 0) or (rb.pos.y < 8 + rb.radius) and (rb.vel.y < 0) then
		rb.vel.y *= -2 + rb.bounce
	end
end

function col_overlap_point(c, p)
	local dist = vec_len_sqr(vec_sub(c.pos, p))
    return dist <= c.radius * c.radius
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

function vec_len_sqr(v)
	return vec_dot(v, v)
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
00666660066666000009999000000000009999880099998800000000000aaa00000aaa0000aaa00000aaa0000070000000007000000000000000000000000000
0666666666666660000990000000999090099888909998883000300000666600006666070aa5aa000aa5aa000000700000000007000000000000000000000000
666666666666666600999990000999999999899909098999330333000aaaaaa00aaaaaa75a565a605a565a600000000000700000000000000000000000000000
66066066660600660090000000909990000990090009900933338330aa5a5aa7aa5a5aaa5aa5aa6a5aa5aa6a0700007000000700000000000000000000000000
06060060060060609090000000900000099999090099990933333333a56565a7a56565aa5a565a6a5a565a6a0070000070000000000000000000000000000000
60060600060600069090000000900000990990990909909933333330aa5a5aa0aa5a5aa75aa5aa6a5aa5aa6a0000700700070000000000000000000000000000
060660606000606090090099900900999000999990009999303333000aaaaa500aaaaa5705aaaa0005aaaa000700000000000000000000000000000000000000
06006066060600600900999899909998900000000990000000000000005555000055550000077000077aa7700000000007000000000000000000000000000000
ccccccccccccccccdcccdcccdcdcdcdcdddcdddcdddcdddcdddddddddddddddd1ddd1ddd1d1d1d1d111d111d111d111d11111111111111110111011101010101
cccccccccccdcccdcdcdcdcdcdcdcdcdcdcdcdcdddddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d11111111111111111111011101010101010101010
ccccccccccccccccccdcccdcdcdcdcdcdcdddcdddcdddcdddddddddddddddddddd1ddd1d1d1d1d1d1d111d111d111d1111111111111111111101110101010101
cccccccccdcccdcccdcdcdcdcdcdcdcdcdcdcdcdddddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d11111111111111111101110111010101010101010
ccccccccccccccccdcccdcccdcdcdcdcdddcdddcdddcdddcdddddddddddddddd1ddd1ddd1d1d1d1d111d111d111d111d11111111111111110111011101010101
cccccccccccdcccdcdcdcdcdcdcdcdcdcdcdcdcdddddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d11111111111111111111011101010101010101010
ccccccccccccccccccdcccdcdcdcdcdcdcdddcdddcdddcdddddddddddddddddddd1ddd1d1d1d1d1d1d111d111d111d1111111111111111111101110101010101
cccccccccdcccdcccdcdcdcdcdcdcdcdcdcdcdcdddddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d11111111111111111101110111010101010101010
00010001000100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01000100010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010001000100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01000100010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
