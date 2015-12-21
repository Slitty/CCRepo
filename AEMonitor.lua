os.loadAPI("eAPI")

ae = peripheral.wrap(eAPI.allPeripherals("me_interface")[1])

function main()
	local total = ae.getTotalBytes()
	local used = total-ae.getFreeBytes()
	term.clear()
	eAPI.centerText(2,"AE MONITOR",colors.purple)
	eAPI.progressBar(5,used/total,"STORAGE CAPACITY")
	eAPI.newln(2)
	if ae.canHoldNewItem() then print("AE can hold |"..ae.getRemainingItemTypes().."| new items") else print("AE CANNOT HOLD NEW ITEMS") end
	print("Used |"..math.floor(used/100).."| kb")
	print("Free |"..math.floor(ae.getFreeBytes()/100).."| kb")
	print("Total |"..math.floor(total/100).."| kb")
end

while true do
	main()
	sleep(1)
end
