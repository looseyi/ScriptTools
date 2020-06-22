#!/usr/bin/env bash

teamid='looseyi'
project_name='Cocoa-Documentation-Example'
root=`pwd`
index_template="$root/docs-index-template"
index_template_url='git@github.com:looseyi/jazzy-template.git'
sdk_path=`xcrun --show-sdk-path --sdk iphonesimulator`

token_business="<li>token-business<\/li>"
template_business="<li\ class=\"nav-group-task\"><a\ class=\"nav-group-task-link\"\ href=\"LIB_URL\">LIB_NAME<wbr><\/a><\/li>"
token_base="<li>token-base<\/li>"
template_base="<li\ class=\"nav-group-task\"><a\ class=\"nav-group-task-link\"\ href=\"LIB_URL\">LIB_NAME<wbr><\/a><\/li>"

# 用于过滤部分无需生成文档的依赖库
ignore_libs=("Alamofire" "SDWebImage")

business_docs=("QMUIKit" "docs")

# get real lib files path
# need to find the real source code folder path
# /A/Classes/...
# /A/src/a/...
# /A/A/Classe/... 
# /A/A/Classes/... 
# /A/A/Source/..
# /A/A/Sources/..
# /A/Source/A/...
# /A/Sources/A/... 
# /A/Source/...
# /A/A/..
# /A/...
# libextobjc/extobjc

get_library_path () {

    # default path
    lower_str=`echo "$1" | awk '{print tolower($1)}'`

    if [ -d $1/src/$lower_str ]; then
        echo $(pwd)/$1/src/$lower_str

    elif [ -d $1/Source/$1 ]; then
        echo $(pwd)/$1/Source/$1

    elif [ -d $1/Sources/$1 ]; then
        echo $(pwd)/$1/Sources/$1

    elif [ -d $1/$1/Source/ ]; then
        echo $(pwd)/$1/$1/Source

    elif [ -d $1/$1/Sources/ ]; then
        echo $(pwd)/$1/$1/Sources

    elif [ -d $1/$1/Class/ ]; then
        echo $(pwd)/$1/$1/Class

    elif [ -d $1/$1/Classes ]; then
        echo $(pwd)/$1/$1/Classes

    elif [ -d $1/$1 ]; then
        echo $(pwd)/$1/$1
        
    elif [ -d $1/Classes ]; then
        echo $(pwd)/$1/Classes

    elif [ -d $1/Source ]; then
        echo $(pwd)/$1/Source

    elif [ -d $1/extobjc ]; then
        echo $(pwd)/$1/extobjc

    elif [ -d $1/NetDiag ]; then
        echo $(pwd)/$1/NetDiag
    else
        echo $(pwd)/$1    
    fi
}

# 由于部分 libray 命名不够规范，这里进行统一
get_lib_docs_name() {
    if [[ $1 = 'docs' ]]; then
        echo 'docs'
    else
        echo "$1-Document"
    fi
}

# 由于业务库代码庞大，建议以单独 repo 来存储文档
document_source() {
    if [[ $1 = 'docs' ]]; then
        echo "git@github.com:$teamid/$project_name.git"
    else
        echo "https://github.com/$teamid/$1-Document.git"
    fi
}

# 判断元素是否存在数组中
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# 解析生成 library
parse_library_doc() {
    input_name="$1"
    
    if [[ $2 = 'subspec' ]]; then
        name=`get_lib_docs_name $input_name`
        subspec_name=`basename $3`
        lib_path=$3
        output_path=$root/$name/docs/$subspec_name
        index_html=$root/$name/docs/index.html
        # echo '1111--------------' $name $input_name $subspec_name
        input_name=$subspec_name
        lib_url="http:\/\/$teamid.github.io\/$name\/$input_name\/index.html"
    else
        lib_path=`get_library_path $input_name`
        output_path=$root/docs/$input_name
        index_html=$root/docs/index.html
        lib_url="http:\/\/$teamid.github.io\/$project_name\/$1\/index.html"
        
        cp "$(dirname $lib_path)/README.md" $lib_path
    fi

    skip=0
    outputs=''

    input_files=`find $lib_path -maxdepth 6 -type f ! -regex '*.\(h\|swift\)' \
        ! -name '*.json' \
        ! -name '*.pdf' \
        ! -name '*.m'`

    mkdir -p $output_path/temp

    for input_file in $input_files; do

        temp_outout=$output_path/temp/$skip.json
        touch $temp_outout

        if [[ "$input_file" == *".swift" ]]; then
            # echo -e '======= input Swift' $input_file
            sourcekitten doc --single-file $input_file -- -j4 $input_file >> $temp_outout
        fi
        
        if [[ "$input_file" == *".h" ]]; then
            # echo -e '======= input Objc' $input_file
            sourcekitten doc --objc \
                    --single-file $input_file \
                    -- -x objective-c \
                    -isysroot $sdk_path \
                    -I $lib_path -fmodules >> $temp_outout
        fi

        file_size=`wc -c $temp_outout | awk '{print $1}'`
        if [ $file_size -gt 0 ]; then
            outputs+=$temp_outout,
            # echo -e '======= outpus' $temp_outout
        fi

        skip=`echo $[skip+1]`
    done

    if [[ "$outputs" == *".json"* ]]; then
        # echo -e '======= outpus' $outputs

        jazzy --theme fullwidth \
            --min-acl private \
            --output $output_path \
            --sourcekitten-sourcefile $outputs
    fi

    if [ -f $output_path/index.html ]; then
        replace_index_html 0 $input_name $lib_url $index_html
    else
        rm -rf $output_path
    fi

    # remove temp output json
    rm -rf $output_path/temp
}

parese_business_doc() {
    libs_path=`get_library_path $1`
    folder_path=`find $libs_path -maxdepth 1 -type d ! -name '.' | sort -n`

    for path in $folder_path; do
        component=`basename $path`
        # ignore parent folder `source`
        if [[ "$path" != "$libs_path" ]]; then
            parse_library_doc $1 'subspec' $path
            # echo 'parese_business_doc' $1 $path $component
        fi
    done

    # 替换索引 tag
    lib_url="http:\/\/$teamid.github.io\/$(get_lib_docs_name $1)\/index.html"
    index_html=$root/docs/index.html
    replace_index_html 1 $1 $lib_url $index_html
}

# 替换索引 tag
replace_index_html() {
    is_business=$1
    if [[ $1 -eq 1 ]]; then
        lib_tag="$template_business"
        lib_token="$token_business"
    else
        lib_tag="$template_base"
        lib_token="$token_base"
    fi
    
    input_name="$2"
    lib_url="$3"
    index_html="$4"
    lib_tag="${lib_tag//LIB_NAME/$input_name}"
    lib_tag="${lib_tag//LIB_URL/$lib_url}"
    sed -i -e "s/$lib_token/$lib_tag$lib_token/g" "$index_html"

    # echo '--------------' $lib_tag
    # echo '-------------- input_name' $input_name
    # echo '-------------- lib_url' $lib_url
    # echo '-------------- index_html' $index_html
}

# 下载 jazzy-template 模版，及业务库模版，将业务库以 submodule 方式嵌入
featch_template () {
    docs_name=`get_lib_docs_name $1`

    cd $root
    

    if [[ $docs_name != 'docs' ]]; then
        docs_name='QMUIKit-Document'
        rm -rf $docs_name
        git submodule add -f $(document_source $1) $docs_name
    
        cd $docs_name
        
        mkdir -p $root/$docs_name/docs
        cp -rf $index_template/index/ $root/$docs_name/docs
    else
        mkdir -p $root/$docs_name
        rm -rf $docs_name
        cp -rf $index_template/index/ $docs_name
    fi
    
    cd $root/Pods
}

# at root_path/$1-docs
deploy_docs() {

    for lib in "${business_docs[@]}"; do
        name=`get_lib_docs_name $lib`
        if [ -d $root/$name ]; then
            cd $root/$name

            find . -maxdepth 8 -type d -name "docsets" | xargs rm -rf

            # Add changes to git.
            git add .

            # Commit changes.
            msg="update $(date)"
            if [ -n "$*" ]; then
                msg="$*"
            fi
            git commit -m "$msg"
            git push origin master
        fi
    done

    rm -rf $root/docs*
    rm -rf $root/*-Document
}

main() {
    mkdir -p $index_template
    git clone $index_template_url $index_template

    featch_template 'docs'

    libs_path=`find . -maxdepth 1 -type d \
        ! -name '*.xcodeproj' \
        ! -name 'Target*' \
        ! -name 'Local*' \
        ! -name 'Headers' \
        ! -name 'Target Support Files' \
        ! -name '*.project_cache' \
        ! -name '.' | sort -n`

    for path in $libs_path; do
        lib_name=`basename "$path"`

        # 过滤多余的 libs
        result=`containsElement $lib_name "${ignore_libs[@]}"`
        result=`echo $result $?`
        if [ $result -eq 0 ]; then 
            continue
        fi

        # for Debug
        # if [[ $lib_name != *'SNB'* ]]; then 
        #     continue
        # fi

        result=`containsElement $lib_name "${business_docs[@]}"`
        result=`echo $result $?`
        if [[ $result -eq 0 ]]; then
            featch_template $lib_name
            parese_business_doc $lib_name
        else
            parse_library_doc $lib_name
            # echo $lib_name
        fi
    done

    deploy_docs
}

main