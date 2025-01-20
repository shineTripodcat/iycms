#!/bin/bash

# 使用说明
echo "使用说明:"
echo "1. ./up.sh hot - 获取周排行榜前10个更新轮播"
echo "2. ./up.sh new - 获取最新更新的10个更新轮播"
echo "3. ./up.sh doubanId=35095038 - 更新指定豆瓣ID的轮播"
echo "4. ./up.sh doubanId=35095038*36013212 - 更新多个豆瓣ID的轮播"

# 启动时间
echo "<h2>轮播数据更新流程</h2>"
echo "启动时间：$(date)"

# 读取配置文件
config_file="config.conf"
if [[ ! -f $config_file ]]; then
    echo "❌ 无法找到数据库配置文件，请在软件根目录中找到配置数据库信息的文件"
    exit 1
fi

# 读取配置
eval $(jq -r 'to_entries | map(select(.key != "dbType")) | .[] | .key + "=" + (.value | @sh)' "$config_file")

# 连接数据库
conn_string="--host=$dbHost --port=$dbPort --user=$dbUser --password=$dbPassword $dbName"

# 根据URL参数决定获取哪种数据
way=${1:-hot}
doubanId=${2:-}

if [[ -n $doubanId ]]; then
    url="http://bbj.icu/BBJ-json?doubanId=$(urlencode "$doubanId")"
    echo "【步骤3】当前模式：指定豆瓣ID更新"
else
    url="http://bbj.icu/BBJ-json?way=$way"
    echo "【步骤3】当前模式：$( [[ $way == 'hot' ]] && echo '每周排行榜' || echo '每日排行榜' )"
fi

# 输出请求的 URL
echo "请求的URL: $url"

# 获取数据
json_data=$(curl -s "$url")

# 输出获取的数据
echo "获取的数据: $json_data"

data=$(echo "$json_data" | jq -c '.[]')

if [[ -z $data ]]; then
    echo "❌ 获取BBJ数据失败或数据格式错误"
    exit 1
fi
echo "✅ BBJ数据获取成功"

# 准备批量更新的数据
echo "【步骤4】处理更新数据..."
update_data=()
processed=0

for item in $data; do
    if [[ $processed -ge 10 ]]; then break; fi

    title=$(echo "$item" | jq -r '.name')
    poster=$(echo "$item" | jq -r '.bbjPosterUrl')

    if [[ -z $title || -z $poster ]]; then continue; fi

    # 查询数据库
    sql="SELECT id FROM videos WHERE title LIKE '%$title%' LIMIT 1;"
    id=$(mysql $conn_string -e "$sql" -s -N)

    if [[ -n $id ]]; then
        update_data+=("$id:$poster")
        echo "✅ 找到匹配记录: $title"
    else
        echo "⚠️ 未找到匹配记录: $title"
    fi

    ((processed++))
done

echo ""

# 如果有需要更新的数据
echo "【步骤5】执行数据更新..."
if [[ ${#update_data[@]} -gt 0 ]]; then
    mysql $conn_string -e "UPDATE videos SET cycle = 2 WHERE cycle = 1;"

    # 构建批量更新SQL
    case_statements=()
    ids=()

    for entry in "${update_data[@]}"; do
        id="${entry%%:*}"
        poster="${entry##*:}"
        # 确保 poster 中的单引号被转义
        poster=$(echo "$poster" | sed "s/'/''/g")
        case_statements+=("WHEN $id THEN '$poster'")
        ids+=("$id")
    done

    ids_string=$(IFS=','; echo "${ids[*]}")
    cases_string=$(IFS=' '; echo "${case_statements[*]}")

    sql="UPDATE videos SET cycle = 1, cycle_img = CASE id $cases_string END WHERE id IN ($ids_string);"

    if ! mysql $conn_string -e "$sql"; then
        echo "❌ 更新数据失败"
    else
        echo "✅ 更新数据成功"
    fi
fi

# 统计更新的记录数
updated_count=${#update_data[@]}
echo "<br>【执行完成】"
echo "总计更新了 $updated_count 条记录的轮播状态和海报。"
echo "结束时间：$(date)"

# 日志部分
LOG_FILE="update.log"
# 检查日志文件是否存在，如果不存在则创建
if [[! -f $LOG_FILE ]]; then
    touch $LOG_FILE
fi
# 追加日志信息
echo "[$(date)] - 启动时间：$(date)，更新模式：${way:-hot}，更新记录数：${updated_count}" >> $LOG_FILE
if [[ -n $doubanId ]]; then
    echo "[$(date)] - 更新的豆瓣ID：$doubanId" >> $LOG_FILE
fi
if [[ ${#update_data[@]} -gt 0 ]]; then
    echo "[$(date)] - 更新的数据：${update_data[*]}" >> $LOG_FILE
fi
if [[ $? -eq 0 ]]; then
    echo "[$(date)] - 更新操作成功" >> $LOG_FILE
else
    echo "[$(date)] - 更新操作失败" >> $LOG_FILE
fi
