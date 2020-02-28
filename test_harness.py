import requests
import time
import random

eci = '2HESZAUwwcvjLntyyhXx5d'

sensors = ['test1', 'test2', 'test3', 'test4']

for i in sensors:
	print("Creating " + i + " sensor.....")
	payload = {'name': i}
	r = requests.get("http://localhost:8080/sky/event/{}/null/sensor/new_sensor".format(eci), params=payload)
	print(r)

time.sleep(2)

print("Getting sensors.....")
r = requests.get("http://localhost:8080/sky/cloud/{}/manage_sensors/sensors".format(eci))

print(r.json())


payload = {'name': 'test3'}
print("Deleting test3 sensor.....")
r = requests.get("http://localhost:8080/sky/event/{}/null/sensor/unneeded_sensor".format(eci), params=payload)
print(r)

time.sleep(2)


print("Getting sensors.....")
r = requests.get("http://localhost:8080/sky/cloud/{}/manage_sensors/sensors".format(eci))

print(r.json())

response = r.json()

print(response)

for i in response:
	child_eci = response[i]['eci']
	print("Adding random temperatures to sensor " + i)
	for j in range(1,10):
		payload = {'genericThing': random.randint(50,90)}
		r = requests.get("http://localhost:8080/sky/event/{}/null/wovyn/heartbeat".format(child_eci), params=payload)
	print(i + " sensor profile:")
	r = requests.get("http://localhost:8080/sky/event/{}/null/sensor/get_profile".format(child_eci))
	print(r.json())

time.sleep(2)

print("Getting all temperatures.....")
r = requests.get("http://localhost:8080/sky/cloud/{}/manage_sensors/get_temps".format(eci))
print(r.json())