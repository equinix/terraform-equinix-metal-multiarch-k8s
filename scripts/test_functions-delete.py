import json
import requests
import os

# This is only used for the "Clean Up" pipeline stage in Drone-- If your name is not Drone, please stop. 

METAL_TOKEN = os.environ['METAL_TOKEN']
KEY_TAG = os.environ['KEY_TAG']

response_keys = requests.get("https://api.equinix.com/metal/v1/ssh-keys", headers={"X-Auth-Token":"%s" % (METAL_TOKEN)}).text
keys = json.loads(response_keys)['ssh_keys']

for key in keys:
    if key['label'].startswith(KEY_TAG):
        print("Deleting %s" % key['id'])
        d = requests.delete("https://api.equinix.com/metal/v1/ssh-keys/%s" % (key['id']), headers={"X-Auth-Token":"%s" % (METAL_TOKEN)})
        print(d.text)
