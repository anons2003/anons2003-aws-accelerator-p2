#!/usr/bin/env bash
# =============================================================================
# install_cloudwatch_agent.sh
# Cài đặt và cấu hình CloudWatch Agent trên EC2 (Amazon Linux 2 / Ubuntu)
#
# Chạy trực tiếp trên EC2 instance (SSH vào trước):
#   bash install_cloudwatch_agent.sh
#
# Yêu cầu:
#   - EC2 instance có IAM Role đính kèm policy: CloudWatchAgentServerPolicy
#   - OS: Amazon Linux 2 hoặc Ubuntu
# =============================================================================
set -euo pipefail

OS_TYPE="${OS_TYPE:-auto}"   # amazon | ubuntu | auto

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      amzn)   echo "amazon" ;;
      ubuntu) echo "ubuntu" ;;
      *)      echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

[[ "$OS_TYPE" == "auto" ]] && OS_TYPE=$(detect_os)

echo "===> Hệ điều hành: $OS_TYPE"

# -----------------------------------------------------------------------------
# Bước 1: Cài đặt CloudWatch Agent
# -----------------------------------------------------------------------------
echo ""
echo "===== BƯỚC 1: Cài đặt CloudWatch Agent ====="

if [[ "$OS_TYPE" == "amazon" ]]; then
  sudo yum install -y amazon-cloudwatch-agent
elif [[ "$OS_TYPE" == "ubuntu" ]]; then
  sudo apt-get update -y
  sudo apt-get install -y amazon-cloudwatch-agent
else
  echo "ERROR: Không xác định được OS. Set OS_TYPE=amazon hoặc OS_TYPE=ubuntu" >&2
  exit 1
fi

echo "✅ Cài đặt xong."

# -----------------------------------------------------------------------------
# Bước 2: Chạy Configuration Wizard
# -----------------------------------------------------------------------------
echo ""
echo "===== BƯỚC 2: Chạy Configuration Wizard ====="
echo "Lệnh dưới đây sẽ mở wizard tương tác — hãy trả lời các câu hỏi:"
echo ""
echo "  sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard"
echo ""
echo "Sau khi wizard hoàn tất, file config sẽ được lưu tại:"
echo "  /opt/aws/amazon-cloudwatch-agent/bin/config.json"
echo ""
read -r -p "Bấm Enter sau khi đã chạy wizard xong để tiếp tục..."

# -----------------------------------------------------------------------------
# Bước 3: Khởi động Agent
# -----------------------------------------------------------------------------
echo ""
echo "===== BƯỚC 3: Enable và Start CloudWatch Agent ====="

sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent

echo "✅ Agent đã được enable và start."

# -----------------------------------------------------------------------------
# Bước 4: Kiểm tra trạng thái
# -----------------------------------------------------------------------------
echo ""
echo "===== BƯỚC 4: Kiểm tra trạng thái Agent ====="

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 -a status | tee /tmp/cw-agent-status.json

echo ""
echo "===== HOÀN THÀNH ====="
echo "CloudWatch Agent đã được cài đặt và khởi động thành công."
echo "Trạng thái đã lưu vào: /tmp/cw-agent-status.json"
