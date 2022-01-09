cd venmo_oracle
mkdir -p pip_wheels
pip3 install wheel
pip3 wheel  --prefer-binary --wheel-dir pip_wheels -r requirements.txt
tar -czvf - pip_wheels | split -b 32M - pip_wheels.tar.gz
rm -rf ./pip_wheels
echo 0x$(cat $(find . -type f | sort) | sha256sum | awk '{print $1}') | tee oracleID.txt
