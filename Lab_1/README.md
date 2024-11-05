# Lab 1: Dùng Terraform và CloudFormation để quản lý và triển khai hạ tầng AWS

## VPC
Tạo một VPC chứa các thành phần sau:
+ Subnets: Bao gồm cả Public Subnet (kết nối với Internet Gateway) và Private
Subnet (sử dụng NAT Gateway để kết nối ra ngoài).
+ Internet Gateway: Kết nối với Public Subnet để cho phép các tài nguyên bên
trong có thể truy cập Internet.
+ Default Security Group: Tạo Security Group mặc định cho VPC
## Route Tables
Tạo Route Tables cho Public và Private Subnet:
+ Public Route Table: Định tuyến lưu lượng Internet thông qua Internet
Gateway.
+ Private Route Table: Định tuyến lưu lượng Internet thông qua NAT Gateway.
## NAT Gateway
Cho phép các tài nguyên trong Private Subnet có thể kết nối Internet mà vẫn bảo đảm tính bảo mật.
## EC2
Tạo các instance trong Public và Private Subnet, đảm bảo Public instance có thể truy cập từ Internet, còn Private instance chỉ có thể truy cập từ Public instance thông
qua SSH hoặc các phương thức bảo mật khác.
## Security Groups
Tạo các Security Groups để kiểm soát lưu lượng vào/ra của EC2 instances:
+ Public EC2 Security Group: Chỉ cho phép kết nối SSH (port 22) từ một IP cụ thể
(hoặc IP của người dùng).
+ Private EC2 Security Group: Cho phép kết nối từ Public EC2 instance thông qua
port cần thiết (SSH hoặc các port khác nếu có nhu cầu).