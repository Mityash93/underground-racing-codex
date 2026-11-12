class_name TrackLayout
extends RefCounted
## Original circuit layout; all positions are in metres, clockwise through three districts.
const RECORD_ID := "neon_v2"
const TUNNEL_START := 70.0
const TUNNEL_END := 270.0
const ANCHORS := [
	Vector3(100, 0, 260), Vector3(-50, 0, 260), Vector3(-200, 0, 260),
	Vector3(-350, 0, 260), Vector3(-450, 0, 140), Vector3(-420, 0, -40),
	Vector3(-290, 0, -190), Vector3(-120, 0, -210), Vector3(0, 0, -165),
	Vector3(140, 0, -230), Vector3(300, 0, -210), Vector3(440, 0, -100),
	Vector3(460, 0, 70), Vector3(360, 0, 210), Vector3(220, 0, 260)]
const COLORS := [Color("39dcea"), Color("ffad58"), Color("64c5ff")]
const NAMES := ["НЕОНОВЫЙ ЦЕНТР", "ПРОМЗОНА «ИСКРА»", "СЕВЕРНАЯ НАБЕРЕЖНАЯ"]
