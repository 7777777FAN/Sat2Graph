#!/bin/bash

gt_dir=/home/godx/research/my_code/exp_repo/graph/Sat2Graph/data/20cities
prop_dir=./model/outputs
path_to_main=./metrics/apls
apls_save_path=./metrics/apls/apls.txt

if [ -e $apls_save_path ]; 
then
    rm $apls_save_path
fi

# 找出生成结果中后缀名为.p的文件，并分词得到文件名
files=$(ls "$prop_dir" | grep '\.p$') # 文件名数组
# 去除后缀
region_numbers=()
for file in $files
do
    single_region_number=$(echo "$file" | cut -d_ -f2)
    region_numbers+=("$single_region_number")
done

region_counter=${#region_numbers[@]}
echo "There are $region_counter regions in total."

# 根据文件名找出其对应的真值.p文件并计算APLS
total_apls=$(echo "scale=16; 0.0" | bc)  # 16位小数
for region_number in "${region_numbers[@]}"
do
    # 根据区域ID找到对应的预测图和真值图的路径
    gt_p_path=${gt_dir}/region_${region_number}_refine_gt_graph.p
    prop_p_path=${prop_dir}/region_${region_number}_output_graph.p

    # 生成该区域的json文件存储路径
    gt_json_path=$path_to_main/json_files/region_${region_number}_gt_graph.json
    prop_json_path=$path_to_main/json_files/region_${region_number}_prop_graph.json

    # 把图的.p文件转换为json文件
    python $path_to_main/convert.py $gt_p_path $gt_json_path
    python $path_to_main/convert.py $prop_p_path $prop_json_path

    # 为各个测试样本分别计算APLS值并向文本文件写入各个样本的计算结果
    go run $path_to_main/main.go $gt_json_path $prop_json_path  $apls_save_path

    # 不断累加他们的APLS值
    single_apls=$(tail -n 1 $apls_save_path | cut -d ' ' -f3)  # tail会忽略末尾的空行，-f3表示获取第三个字段，也就是一张测试影像的平均APLS
    total_apls=$(echo "scale=16; ${total_apls} + ${single_apls}" | bc) 
done

# 最后向文本文件追加他们的总的平均APLS值
avg_apls=$(echo "scale=16; ${total_apls} / ${region_counter}" | bc)
echo "Total Average APLS: $(printf '%.16f' $avg_apls)" >> $apls_save_path   # >> 表示追加, 采用printf格式化输出，使其包含整数部分，也即0.xxxx而非.xxxx