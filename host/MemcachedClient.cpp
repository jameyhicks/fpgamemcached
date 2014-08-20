#include "MemcachedClient.h"
#include "GeneratedTypes.h"
#include <unistd.h>
#include <math.h>

// xbvs-related


//#include "protocol_binary.h"

MemcachedClient::MemcachedClient(){
   indication = new ServerIndication(IfcNames_ServerIndication);
   device = new ServerRequestProxy(IfcNames_ServerRequest);

   pthread_t tid;
   fprintf(stderr, "Constructor::creating exec thread\n");
   if(pthread_create(&tid, NULL,  portalExec, NULL)){
      fprintf(stderr, "Constructor::error creating exec thread\n");
      exit(1);
   }
}

bool MemcachedClient::set(const void* key,
                          size_t keylen,
                          const void* dta,
                          size_t dtalen){
   //pthread_mutex_lock(&(indication->mu));
   //size_t bufsz = sizeof(protocol_binary_request_header) + keylen + dtalen; 
   //char* buf = new char[bufsz];

   // printf("bufsize = %d\n", bufsz);
   
   //generate_command(buf, bufsz, PROTOCOL_BINARY_CMD_SET, key, keylen, dta, dtalen);
   
   //send_binary_protocol(buf, bufsz);

  printf("shit\n");
   
  while (!indication->sysReady());
  indication->resetSys(false);
  indication->resetDta(false);
  //usleep(1000000);
  //delete buf;
  device->receive_cmd(gen_req_header(Protocol_Binary_Command_PROTOCOL_BINARY_CMD_SET, key, keylen, dta, dtalen));

  uint64_t* k = (uint64_t*)key;
  size_t keyCnt = keylen;
  while ( keyCnt >= 8){
    device->receive_key(*k);
    k++;
    keyCnt -= 8;
  }

  char* ckey = (char*)key;
  printf("64bit key = %016x, mask = %016x, keyCnt = %d\n", *k, (((uint64_t)1 << (keyCnt*8))-1), keyCnt);
  printf("key[0] = %02x\n", ckey[0]);
  printf("key[1] = %02x\n", ckey[1]);
  printf("key[2] = %02x\n", ckey[2]);
  printf("key[3] = %02x\n", ckey[3]);
  printf("key[4] = %02x\n", ckey[4]);
  uint64_t lastkey = 0;
  if ( keyCnt != 0) {
    device->receive_key((*k) &  (((uint64_t)1 << (keyCnt*8))-1));
  }

  while(!indication->dtaReady());
  
  printf("Start sending the data\n");

  uint64_t* d = (uint64_t*)dta;
  size_t dtaCnt = dtalen;
  while ( dtaCnt >= 8){
    device->receive_dta(*d);
    d++;
    dtaCnt -= 8;
  }

  uint64_t lastdta = 0;
  if ( dtaCnt != 0) {
    device->receive_dta((*d) &  (((uint64_t)1 << (dtaCnt*8))-1));
  }

  indication->resetSys(true);
  indication->resetDta(false);
  return true;
}
   
   

//while (!(indication->flag)){}
   //pthread_cond_wait(&(indication->cond), &(indication->mu));
   //pthread_mutex_unlock(&(indication->mu));
//}

char* MemcachedClient::get(char* key, size_t keylen){
  while (!indication->sysReady());
  indication->resetSys(false);
  indication->resetDta(false);
   
  device->receive_cmd(gen_req_header(Protocol_Binary_Command_PROTOCOL_BINARY_CMD_GET, key, keylen, NULL, 0));

  uint64_t* k = (uint64_t*)key;
  size_t keyCnt = keylen;
  while ( keyCnt >= 8){
    device->receive_key(*k);
    k++;
    keyCnt -= 8;
  }

  uint64_t lastkey = 0;
  if ( keyCnt != 0) {
    device->receive_key((*k) &  (((uint64_t)1 << (keyCnt*8))-1));
  }

  while(!indication->dtaReady());
  
  indication->resetSys(true);
  indication->resetDta(false);

  return indication->data;
}

void MemcachedClient::initSystem(int size1,
                                 int size2,
                                 int size3,
                                 int addr1,
                                 int addr2,
                                 int addr3){
  int lgSz1 = (int)log2((double)size1);
  int lgSz2 = (int)log2((double)size2);
  int lgSz3 = (int)log2((double)size3);

  if ( lgSz2 <= lgSz1 ) lgSz2 = lgSz1+1;
  if ( lgSz3 <= lgSz2 ) lgSz3 = lgSz2+1;

  int lgAddr1 = (int)log2((double)addr1);
  int lgAddr2 = (int)log2((double)addr2);
  int lgAddr3 = (int)log2((double)addr3);

  if ( lgAddr2 <= lgAddr1 ) lgAddr2 = lgAddr1+1;
  if ( lgAddr3 <= lgAddr2 ) lgAddr3 = lgAddr2+1;

  device->initValDelimit(lgSz1, lgSz2, lgSz3);
  device->initAddrDelimit(lgAddr1, lgAddr2, lgAddr3);

}

Protocol_Binary_Request_Header MemcachedClient::gen_req_header(Protocol_Binary_Command cmd,
                                                               const void* key,
                                                               size_t keylen,
                                                               const void* dta,
                                                               size_t dtalen){
   Protocol_Binary_Request_Header request;
   memset(&request, 0, sizeof(request));
   request.magic = Protocol_Binary_Magic_PROTOCOL_BINARY_REQ;
   request.opcode = cmd;
   request.keylen = keylen;
   request.bodylen = keylen + dtalen;
   request.opaque = 0xdeadbeef;

   return request;
}


/*
void MemcachedClient::generate_command(char* buf,
                                       size_t bufsz,
                                       uint8_t cmd,
                                       const void* key,
                                       size_t keylen,
                                       const void* dta,
                                       size_t dtalen) {

   protocol_binary_request_no_extras *request = (protocol_binary_request_no_extras*)buf;
   assert(bufsz == sizeof(*request) + keylen + dtalen);

   memset(request, 0, sizeof(*request));
   request->message.header.request.magic = PROTOCOL_BINARY_REQ;
   request->message.header.request.opcode = cmd;
   request->message.header.request.keylen = keylen;
   request->message.header.request.bodylen = keylen + dtalen;
   request->message.header.request.opaque = 0xdeadbeef;

   off_t key_offset = sizeof(protocol_binary_request_no_extras);

   //if (key != NULL) {
   memcpy(buf + key_offset, key, keylen);
      //}
      // if (dta != NULL) {
   memcpy(buf + key_offset + keylen, dta, dtalen);
      // }                                                 
}
*/
/*
void MemcachedClient::send_binary_protocol(const char* buf, size_t bufsz){
   uint32_t send_word;

   off_t buf_offset = 0;

   size_t step_sz = sizeof(send_word);

   while (buf_offset + step_sz <= bufsz){
      memcpy(&send_word, buf + buf_offset, step_sz);
      printf("%08x\n", send_word);
      device->receive_cmd(send_word);
      buf_offset+=step_sz;
   }

   if (buf_offset < bufsz) {
      send_word = 0;
      memcpy(&send_word, buf + buf_offset, bufsz - buf_offset);
      printf("%08x\n", send_word);
      device->receive_cmd(send_word);
   }
}
*/




/*
  fprintf(stderr, "Main::calling say1(%d)\n", v1a);
  device->say1(v1a);  
  fprintf(stderr, "Main::calling say2(%d, %d)\n", v2a,v2b);
  device->say2(v2a,v2b);
  fprintf(stderr, "Main::calling say3(S1{a:%d,b:%d})\n", s1.a,s1.b);
  device->say3(s1);
  fprintf(stderr, "Main::calling say4(S2{a:%d,b:%d,c:%d})\n", s2.a,s2.b,s2.c);
  device->say4(s2);
  fprintf(stderr, "Main::calling say5(%08x, %016zx, %08x)\n", v5a, v5b, v5c);
  device->say5(v5a, v5b, v5c);  
  fprintf(stderr, "Main::calling say6(%08x, %016zx, %08x)\n", v6a, v6b, v6c);
  device->say6(v6a, v6b, v6c);  
  fprintf(stderr, "Main::calling say7(%08x, %08x)\n", s3.a, s3.e1);
  device->say7(s3);  

  fprintf(stderr, "Main::about to go to sleep\n");
  while(true){sleep(2);}
*/
