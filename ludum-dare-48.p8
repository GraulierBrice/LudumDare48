pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function _init()
	physics_start(1/30)
	init_bullets(128)
	spawn_player()
end

function _update()
    cls()
	update_player()
	update_bullets()
	physics_update()
end

function _draw()
	col_draw(colliders[1])
	draw_bullets()
end

-->8
--player

function spawn_player()
	player=rigidbody(64, 64, 0, 8, 8, 0, 0, 0, nil)
	player.firerate=0.25
	player.nextshoot=0
end

function update_player()
	player.acc.y=32
	if time()>player.nextshoot then
		if btn(0) or btn(1) or btn(2) or btn(3) then
			local dir = nil
			if btn(0) 	  then dir = vector(-1,0)
			elseif btn(1) then dir = vector(1,0)
			elseif btn(2) then dir = vector(0,-1)
			elseif btn(3) then dir = vector(0,1) end
			local b=bullet_straight(player.pos, vec_mul(dir, vector(32,32)), 7, 0)
			player.nextshoot = time() + player.firerate
			player.vel = vec_add(player.vel, vec_mul(vector(-32,-32), dir))
		end
	end
end

-->8
-- bullets

function init_bullets(n)
	bullets={}
	for i=1,n do
		add(bullets, {pos=vector(0,0), move=nil, color=0, flag=0, lifetime=0})
	end
	bullets.first=1
end

function bullet_straight(pos, vel, color, flag)
	local b = bullet(pos, color, flag)
	b.vel=vector(vel.x, vel.y)
	b.move=bullet_straight_move
	return b
end

function bullet_straight_move(b)
	b.pos = vec_add(b.pos, vec_mul(b.vel, vector(phy.dt, phy.dt)))
end

function bullet(pos, color, flag)
	local b = bullets[bullets.first]
	b.pos=vector(pos.x, pos.y)
	b.color=color
	b.flag=flag
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

function rigidbody(x, y, r, w, h, friction, drag, bounce, on_hit)
	local rb = collider(x, y, r, w, h, false, on_hit)
	rb.acc = vector(0, 0)
	rb.vel = vector(0, 0)
	rb.mom = 0
	rb.tor = 0
    rb.friction = friction
    rb.drag = drag
    rb.bounce = bounce
	add(rigidbodies, rb)
	return rb
end

function collider(x, y, r, w, h, trg, on_hit, ign)
	local c = transform(x, y, r)
	c.w = w
	c.h = h
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
			local loc_hit = inv_tr_point(data.new_col, hit)
			local loc_hit_norm = inv_tr_vector(data.new_col, norm)
			local loc_hit_tan =  mul_mat_vec(rot_matrix(0.25), loc_hit_norm)
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

	local new_tor = rb.tor - rb.mom * rb.drag
	local new_mom = rb.mom + new_tor * phy.dt
	local new_rot = rb.rot + new_mom * phy.dt

	local new_col = collider(new_pos.x, new_pos.y, new_rot, rb.w, rb.h, false, rb.on_hit, true)
	
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
	rb.mom = new_mom
	rb.rot = new_rot % 1
	
end

function col_overlap_point(c, p)
	local q=tr_point(c, p)
	local ul=col_loc_ul_corner(c)
	local br=col_loc_br_corner(c)

	return ul.x <= q.x and q.x <= br.x and br.y <= q.y and q.y <= ul.y
end

function col_overlap_col(c1, c2)
	local pts={}
	if (col_overlap_point(c1, col_ur_corner(c2))) add(pts, col_ur_corner(c2))
	if (col_overlap_point(c1, col_ul_corner(c2))) add(pts, col_ul_corner(c2))
	if (col_overlap_point(c1, col_br_corner(c2))) add(pts, col_br_corner(c2))
	if (col_overlap_point(c1, col_bl_corner(c2))) add(pts, col_bl_corner(c2))
	if (col_overlap_point(c2, col_ur_corner(c1))) add(pts, col_ur_corner(c1))
	if (col_overlap_point(c2, col_ul_corner(c1))) add(pts, col_ul_corner(c1))
	if (col_overlap_point(c2, col_br_corner(c1))) add(pts, col_br_corner(c1))
	if (col_overlap_point(c2, col_bl_corner(c1))) add(pts, col_bl_corner(c1))
	if (#pts > 0) then
		local contact = vector(0,0)
		for i=1,#pts do
			contact = vec_add(contact, pts[i])
		end
		contact = vec_mul(contact, vector(1/#pts, 1/#pts))
		return contact
	end
	return false
end

function col_normal(c, p)
	local q=tr_point(c, p)
	local n
	local angle = atan2(q.x, q.y)
	local threshold = 0.125--atan2(c.w/2, c.h/2)
		if (angle<threshold)  then n = col_left(c)
	elseif (angle==threshold) then n = vec_add(col_left(c), col_up(c))
	elseif (angle<threshold*3)  then n = col_up(c)
	elseif (angle==threshold*3) then n = vec_add(col_right(c), col_up(c))
	elseif (angle<threshold*5)  then n = col_right(c)
	elseif (angle==threshold*5) then n = vec_add(col_right(c), col_down(c))
	elseif (angle<threshold*7)  then n = col_down(c)
	elseif (angle==threshold*7) then n = vec_add(col_left(c), col_down(c))
	else                       n = col_left(c)
	end
	return vec_norm(n)
end

function col_draw(c)
	local ul=col_ul_corner(c)
	local br=col_br_corner(c)
	local bl=col_bl_corner(c)
	local ur=col_ur_corner(c)

	line(ur.x, ur.y, br.x, br.y)
	line(ur.x, ur.y, ul.x, ul.y)
	line(br.x, br.y, bl.x, bl.y)
	line(ul.x, ul.y, bl.x, bl.y)
end

function col_up(c)
	return inv_tr_vector(c, col_loc_up(c))
end

function col_down(c)
	return inv_tr_vector(c, col_loc_down(c))
end

function col_left(c)
	return inv_tr_vector(c, col_loc_left(c))
end

function col_right(c)
	return inv_tr_vector(c, col_loc_right(c))
end

function col_ul_corner(c)
	return vec_add(c.pos, vec_add(col_up(c), col_left(c)))
end

function col_ur_corner(c)
	return vec_add(c.pos, vec_add(col_up(c), col_right(c)))
end

function col_bl_corner(c)
	return vec_add(c.pos, vec_add(col_down(c), col_left(c)))
end

function col_br_corner(c)
	return vec_add(c.pos, vec_add(col_down(c), col_right(c)))
end

function col_loc_up(c)
	return vector(0,c.h*0.5)
end

function col_loc_down(c)
	return vector(0,-c.h*0.5)
end

function col_loc_left(c)
	return vector(-c.w*0.5,0)
end

function col_loc_right(c)
	return vector(c.w*0.5,0)
end

function col_loc_ul_corner(c)
	return vec_add(col_loc_up(c), col_loc_left(c))
end

function col_loc_ur_corner(c)
	return vec_add(col_loc_up(c), col_loc_right(c))
end

function col_loc_bl_corner(c)
	return vec_add(col_loc_down(c), col_loc_left(c))
end

function col_loc_br_corner(c)
	return vec_add(col_loc_down(c), col_loc_right(c))
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

function matrix(c00, c01, c10, c11)
	return {c00, c01, c10, c11}
end

function mtx_inv(m)
	local d=m[1]*m[4]-m[2]*m[3]
	if (d!=0) then
		return matrix(d*m[4], -d*m[2], -d*m[3], d*m[1])
	else
		return m
	end
end

function rot_matrix(a)
	local c=cos(a)
	local s=sin(a)
	return matrix(c, -s, s, c)
end

function mul_mat_vec(m, v)
	return vector(m[1]*v.x + m[2]*v.y, m[3]*v.x + m[4]*v.y)
end

function transform(x, y, rot)
	return {pos=vector(x, y), rot=rot}
end

function tr_vector(t, v)
	return mul_mat_vec(rot_matrix(t.rot), v)
end

function tr_point(t, p)
	return tr_vector(t, vec_sub(p, t.pos))
end

function inv_tr_vector(t, v)
	return mul_mat_vec(mtx_inv(rot_matrix(t.rot)), v)
end

function inv_tr_point(t, p)
	return vec_add(t.pos, inv_tr_vector(t, vec_sub(p, t.pos)))
end

function tr_up(t)
	return tr_vector(t, vector(0,1))
end

function tr_down(t)
	return tr_vector(t, vector(0,-1))
end

function tr_right(t)
	return tr_vector(t, vector(1,0))
end

function tr_left(t)
	return tr_vector(t, vector(-1,0))
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
