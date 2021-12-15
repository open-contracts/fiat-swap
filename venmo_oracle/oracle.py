import opencontracts
from bs4 import BeautifulSoup
import email, os

with opencontracts.enclave_backend() as enclave:
  while True:
    cmd = enclave.user_input('Enter some linux command:')
    if cmd == 'done': break
    try:
      os.system(cmd)
    except Exception as e:
      enclave.print(e)
  
  import requests
  enclave.print(requests.get('https://ifconfig.me').text)
