import opencontracts
from bs4 import BeautifulSoup
import email, os, requests

with opencontracts.enclave_backend() as enclave:
  while True:
    cmd = enclave.user_input('Enter some python command:')
    if cmd == 'done': break
    try:
      eval(cmd)
    except Exception as e:
      enclave.print(e)

  enclave.print(requests.get('https://ifconfig.me').text)
