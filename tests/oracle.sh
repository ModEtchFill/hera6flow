set -e # exit on cmd return 
if [ x$GOPATH = x ]
then
  # when running in github actions workflow
  export GOPATH=$PWD/testrun
  mkdir -p testrun/src/github.com/paypal
  ln -s $PWD testrun/src/github.com/paypal/hera
fi

sudo apt install libboost-regex-dev -y
wget -nv https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basiclite-linux.x64-19.19.0.0.0dbru.zip https://download.oracle.com/otn_software/linux/instantclient/1920000/instantclient-sqlplus-linux.x64-19.20.0.0.0dbru.zip
curl -O https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-sdk-linux.x64-19.19.0.0.0dbru.zip
echo 409b867f76c701ccba47f9278363b204137fc92444c317b36b60da35669453a99bd02a3c84b1b9b92c54fd94929a0eff  instantclient-sqlplus-linux.x64-19.20.0.0.0dbru.zip >> SHA384
echo bb68094a12e754fc633874e8c2b4c4d38a45a65a5a536195d628d968fca72d7a5006a62a7b1fdd92a29134a06605d2b4  instantclient-basiclite-linux.x64-19.19.0.0.0dbru.zip >> SHA384
echo 5999f2333a9b73426c7af589ab13480f015c2cbd82bb395c7347ade37cc7040a833a398e9ce947ae2781365bd3a2e371  instantclient-sdk-linux.x64-19.19.0.0.0dbru.zip >> SHA384
sha384sum -c SHA384
pubdir=$PWD

pushd /opt
mkdir instantclient_19
ln -s instantclient_19 instantclient_19_17
ln -s instantclient_19 instantclient_19_19
ln -s instantclient_19 instantclient_19_20
unzip $pubdir/instantclient-basiclite-linux.x64-19.19.0.0.0dbru.zip
unzip $pubdir/instantclient-sdk-linux.x64-19.19.0.0.0dbru.zip
unzip $pubdir/instantclient-sqlplus-linux.x64-19.20.0.0.0dbru.zip
popd

export ORACLE_HOME=/opt/instantclient_19
mkdir -p $ORACLE_HOME/network/admin
echo 'TEST3=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(Host=localhost)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XEPDB1)(FAILOVER_MODE=(TYPE=SESSION)(METHOD=BASIC)(RETRIES=1000)(DELAY=5)))))' > $ORACLE_HOME/network/admin/tnsnames.ora
find $ORACLE_HOME/network -ls
export TWO_TASK=TEST3
export TNS_ADMIN=./
export OPS_CFG_FILE=occ.cdb
export username=system
export password=1.2.8MomOfferExpand
if [ x$LD_LIBRARY_PATH = x ]
then
    export LD_LIBRARY_PATH=$ORACLE_HOME
else
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME
fi
cat <<EOF |$ORACLE_HOME/sqlplus $username/$password@$TWO_TASK
create or replace function cur_micros
return number
is
    rv number;
    upper number;
begin
    select to_number(to_char(current_timestamp,'SSFF')) into rv from dual;
    select to_number(to_char(current_timestamp,'MI')) into upper from dual;
    rv := rv + 1000000 * 60 * upper;
    -- adding hh24 overflows
    return rv;
end;
/
select cur_micros() from dual;
select cur_micros() as chkStmtSpeed from dual;
create or replace function usleep (micros in number)
return number
is
    finish number;
    cur number;
begin
    cur := cur_micros();
    finish := cur + micros;
    while cur < finish loop
        cur := cur_micros();
    end loop;
    return cur-finish+micros;
end;
/
select current_timestamp from dual;
select usleep(2111000) from dual;
select current_timestamp from dual;
create public synonym usleep for usleep;
--grant execute on usleep to app;

create table resilience_at_load ( id number, note varchar2(333) );
create public synonym resilience_at_load for resilience_at_load;
EOF

# make oracle worker
pushd worker/cppworker/worker
make -f ../build/makefile19 -j 3
mkdir -p $GOPATH/bin
cp -v oracleworker $GOPATH/bin/
popd


# run test with oracle
touch state.log hera.log
tail -f state.log hera.log &
#for d in state.log hera.log
#do 
#    touch $d
#    tail -f $d | sed -e "s/^/$d /" &
#done
( rm -f zstop ; while [ ! -f zstop ] ; do tail cal.log ;  sleep 1.1 ; done ) &
sleep 1.2
date >> cal.log
date >> hera.log
sleep 1.5
echo $RANDOM >> cal.log
echo $RANDOM >> hera.log
sleep 1.7
chmod a+w cal.log state.log hera.log
d=oracleHighLoadAdj
pushd $GOPATH/src/github.com/paypal/hera/tests/unittest2/$d
cp -v $GOPATH/bin/oracleworker .
#( ./oracleworker ; echo $? tried oracleworker with failure expected )
$GOROOT/bin/go test -c .
ls -l
#timeout -v 222 strace -ttfs111 -e trace=open,write,read ./$d.test -test.v | tee /dev/null
timeout -v --kill-after=444 222 ./$d.test -test.v
rv=$?
if [ 0 != $rv ]
then
    echo failing $suite $d
    grep ^ *.log
fi
touch zstop 
ls -l
grep ORA hera.log | head
tail *.log
grep WORKER hera.log | head
echo test done $rv
exit $rv
