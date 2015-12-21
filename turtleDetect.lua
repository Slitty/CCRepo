os.loadAPI("ocs/apis/sensor")
local s = sensor.wrap("top")
local url = ""
local pos={1,1,1}
local first = true
local args = {...}

function post(text,write)
	http.post(url.."?message="..textutils.urlEncode(text))
	if write then print(text) end
end

function main()
	for num,x in pairs(s.getTargets()) do
		if x.Name:find("Turtle") then
			if first then post("CLEAR") first = false end
			post(x.Name.." | Target# "..num,true)
			post("X:"..x.Position.X+pos[1].." Y:"..x.Position.Y+pos[2].." Z:"..x.Position.Z+pos[3],true) 
			local dist=math.sqrt(math.pow(x.Position.X-pos[1],2)+math.pow(x.Position.Y-pos[2],2)+math.pow(x.Position.Z-pos[3],2))
			post("Distance | "..math.floor(dist).." | Blocks",true)
			post("----------------------",true)
		end
	end
	print("Targets : "..#s.getTargets())
end

while true do
	main()
	sleep(5)
end
