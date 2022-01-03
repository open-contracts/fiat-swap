import opencontracts
from bs4 import BeautifulSoup
import email

with opencontracts.enclave_backend() as enclave:

  enclave.print(f"Hello {enclave.user()}! Fiat Swap started running in the Enclave.")
  seller = enclave.user_input("Please enter the Venmo handle of the seller:")
  price = int(enclave.user_input("Please enter the transaction price in cents (as integer):"))
  message = enclave.user_input("Please enter the message the seller wants you to use in the transaction:").strip()
  service = "Venmo"   # allow user to input one of multiple options in the future
  secret = enclave.user_input("Please enter the secret generated by the seller:")
  
  offerID = enclave.keccak(seller, price, message, service, secret, types=('string', 'uint256', 'string', 'string', 'string'))
  warning = f"""
  The information you entered would produce the offerID:
  {'0x' + offerID.hex()}
  Before proceeding to make a payment, call weiOffered() to verify you will receive enough tokens.
  """
  enclave.print(warning)
   
  instructions = f"""
  1) Pay ${price/100} to {seller} and use the message '{message}'.
  2) Navigate to {seller}'s account page
  3) Go to the 'Between You' tab 
  4) Click the 'Submit' button on the right.
  """
  
  def parser(mhtml):
    mhtml = email.message_from_string(mhtml.replace("=\n", ""))
    url = mhtml['Snapshot-Content-Location']
    target_url = f'https://account.venmo.com/u/{seller}'
    assert url==target_url, f"You hit 'Submit' on '{url}', but should do so on '{target_url}'."
    html = [_ for _ in mhtml.walk() if _.get_content_type() == "text/html"][0]
    parsed = BeautifulSoup(html.get_payload(decode=False))
    transactions = parsed.find_all(**{'data-testid' :'3D"betweenYou-feed-container"'})[0]
    transactions = transactions.findAll('div', {'class': lambda c: c and c.startswith('3D"storyContent_')})
    transactions = map(lambda t: (t.text.strip(), t.findParent().findParent().findNextSibling().text.strip()), transactions)
    transactions = list(filter(lambda t: (t[0]==message) and t[1].startswith("- $"), transactions))
    payment = sum(map(lambda t: int(float(t[1][3:])*100), transactions))
    assert payment >= price, f"Found {len(transactions)} payments labeled '{message}', adding up to ${payment/100} which is too low."
    return payment
  
  payment = enclave.interactive_session(url='https://venmo.com', parser=parser, instructions=instructions)
  enclave.print(f'Your total payment of ${payment/100} to {seller} was confirmed.')
  enclave.submit(enclave.user(), offerID, types=("address", "bytes32"), function_name="buyTokens")
