#!/usr/bin/env sh

# The repository of moses, we need to download some scripts from moses.
# https://github.com/moses-smt/mosesdecoder/tree/master/scripts
mose_git=https://github.com/moses-smt/mosesdecoder/tree/master/scripts

echo 'Select the source language: en, cs, fi, fr, ru, de'
read -p '==> ' source_language
echo "The selected source language is $source_language"


echo 'Select the target language: en, cs, fi, fr, ru, de'
read -p '==> ' target_language
echo "The selected target language is $target_language"

if [ $target_language = $source_language ]
then
    echo 'Languages should be different'
    read -p ' ' aaa
    exit -1
fi

if [ ! -d 'share/nonbreaking_prefixes' ]
then
    mkdir -p share/nonbreaking_prefixes 
fi

echo "Downloading nonbreaking_prefix $source_language ..."
curl -s $mose_git/share/nonbreaking_prefixes/nonbreaking_prefix.$source_language > share/nonbreaking_prefixes/nonbreaking_prefix.$source_language
echo "Downloading nonbreaking_prefix $target_language ..."
curl -s $mose_git/share/nonbreaking_prefixes/nonbreaking_prefix.$target_language > share/nonbreaking_prefixes/nonbreaking_prefix.$target_language

if [ ! -d 'data' ]
then
    echo 'Creating data directory...'
    mkdir data
fi



cp preprocess/create_vocab.py preprocess/shuffle_data.py data/

echo 'cd to data directory'
cd data
if [ ! -f tokenizer.perl ]
then
    echo 'Downloading tokenizer.perl'
    curl -s $mose_git/tokenizer/tokenizer.perl > tokenizer.perl
fi
if [ ! -f multi-bleu.perl ]
then
    echo 'Downloading multi-bleu.perl'
    curl -s $mose_git/generic/multi-bleu.perl > multi-bleu.perl
fi

echo 'Please download corresponding datasets from WMT15 manually and put the parallel corpus in the data directory'
echo 'Then enter the file name of source language dataset'
read -p '==> ' source_data
echo 'The file name of target language dataset'
read -p '==> ' target_data

if [ ! -f $source_data ]; then
    echo 'No such source dataset file'
    exit -1
fi

if [ ! -f $target_data ]; then
    echo 'No such target dataset file'
    exit -1
fi

tok_source_file=all.$source_language-$target_language.$source_language.tok
tok_target_file=all.$source_language-$target_language.$target_language.tok

perl tokenizer.perl -l $source_language -threads 4 -no-escape < $source_data > $tok_source_file
perl tokenizer.perl -l $target_language -threads 4 -no-escape < $target_data > $tok_target_file

echo 'Please put test dataset in the data directory'
echo 'The file name of source test set:'
read -p '==>' src_test
echo 'The file name of targe test set:'
read -p '==>' trg_test

if [ ! -f $src_test ]; then
    echo 'No such source test file'
    exit -1
fi

if [ ! -f $trg_test ]; then
    echo 'No such target test file'
    exit -1
fi

perl tokenizer.perl -l $source_language -threads 4 -no-escape < $src_test > $src_test.tok
perl tokenizer.perl -l $target_language -threads 4 -no-escape < $trg_test > $trg_test.tok


echo 'Please ensure there is enough disk space'
python shuffle_data.py $tok_source_file $tok_target_file

echo 'Please enter the size of source language vocabulary (120 is enough):'
read -p '==>' src_vocab_size
echo 'Please enter the size of target language vocabulary (120 is enough):'
read -p '==>' trg_vocab_size
python create_vocab.py $source_language $target_language $src_vocab_size $trg_vocab_size $tok_source_file.shuf $tok_target_file.shuf

cd ..
if [ -f configurations.py ]; then
    cp configurations.py configurations_backup.py
fi 

cp configurations_template.py configurations.py

sed -i "s/--src_lang--/$source_language/" configurations.py
sed -i "s/--trg_lang--/$target_language/" configurations.py
sed -i "s/--src_vocab_size--/$src_vocab_size/" configurations.py
sed -i "s/--trg_vocab_size--/$trg_vocab_size/" configurations.py
sed -i "s/--src_test--/$src_test/" configurations.py
sed -i "s/--trg_test--/$trg_test/" configurations.py

echo "OK! Just run 'python training_adam.py'"

