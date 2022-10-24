aws s3 mb s3://may-test-2022
aws s3api put-bucket-versioning --bucket may-test-2022 --versioning-configuration MFADelete=Disabled,Status=Enabled
touch test.txt
echo Hello from text file >> test.txt
aws s3 cp test.txt s3://may-test-2022