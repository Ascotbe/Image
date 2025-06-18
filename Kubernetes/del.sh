#!/bin/bash

# 检查是否提供了 Agent 名称参数
if [ "$#" -ne 1 ]; then
    echo "用法: $0 <agent_name>"
    echo "示例: sudo $0 xiaomi"
    exit 1
fi

# 从命令行参数获取 Agent 名称
AGENT_NAME="$1"

# 检查 expect 工具是否安装
if ! command -v expect &> /dev/null
then
    echo "错误：'expect' 工具未安装。请在 Wazuh Server 上运行以下命令安装："
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install expect"
    echo "  CentOS/RHEL/Fedora: sudo yum install expect (或 dnf install expect)"
    exit 1
fi

echo "正在尝试删除 Wazuh Agent '${AGENT_NAME}' ..."

# 1. 获取Agent ID
AGENT_ID=$(sudo grep -i "${AGENT_NAME}" /var/ossec/etc/client.keys | awk '{print $1}' 2>/dev/null)

# 检查是否找到Agent ID
if [ -z "$AGENT_ID" ]; then
    echo "错误：Wazuh Agent '${AGENT_NAME}' 未找到或其ID无法确定。请检查名称或/var/ossec/etc/client.keys文件。"
    exit 1
fi

echo "找到 Agent ID: ${AGENT_ID}"

# 2. 使用expect自动化删除过程
if sudo expect -c "
    set timeout -1
    spawn /var/ossec/bin/manage_agents
    # 等待主菜单提示 (已验证过，应该没问题)
    expect \"Choose your action: A,E,L,R or Q: \"
    send \"R\n\"
    # ==== 再次修改这一行，在末尾的冒号后添加一个空格 ====
    expect -re {Provide the ID of the agent to be removed \(or '\\\\q' to quit\):\s*}    
    send \"${AGENT_ID}\n\"
    # 等待确认提示 (这一行看起来没问题，但如果还是卡住，也可能需要检查转义或末尾空格)
    expect \"Confirm deleting it?(y/n): \"
    send \"y\n\"
    expect \"Choose your action: A,E,L,R or Q: \"
    send \"Q\n\"
    expect eof
"
then
    echo "Wazuh Agent '${AGENT_NAME}' (ID: ${AGENT_ID}) 已成功发送删除指令。请检查Wazuh Server日志以确认删除结果。"
else
    echo "错误：Wazuh Agent '${AGENT_NAME}' (ID: ${AGENT_ID}) 删除过程失败。请检查 expect 命令的输出和 Wazuh Server 日志。"
    exit 1
fi