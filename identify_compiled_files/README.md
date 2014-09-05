    sudo ./identify.pl ./linux_kernel/linux-3.16.1 'export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu && make -j8 bzImage'
    
    ctags -L compiled.files -f .tags
    
    cscope -b -q -k -i compiled.files
    
    ./search.sh compiled.files "function_name"
