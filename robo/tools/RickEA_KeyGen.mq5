//+------------------------------------------------------------------+
//|                                                RickEA_KeyGen.mq5 |
//|         Gerador de licencas do RickEA MA (uso do vendedor)       |
//|                                                                  |
//|  Script. Copie para MQL5\Scripts, compile (F7) e execute em      |
//|  qualquer grafico. Ele imprime a chave no "Experts", mostra num  |
//|  Alert (da pra copiar com Ctrl+C) e guarda em                    |
//|  MQL5\Files\RickEA_Licencas.csv.                                 |
//|                                                                  |
//|  O SEGREDO precisa ser IGUAL ao do RickEA_MA_Vendas.mq5.         |
//|  NUNCA entregue este arquivo (nem o .ex5 dele) a um cliente.     |
//+------------------------------------------------------------------+
#property copyright "RichardTrader"
#property link      "RICKEA MA"
#property version   "1.00"
#property script_show_inputs
#property description "Gera as chaves de licenca do RickEA MA."

#define RICK_LICENSE_SECRET  "TROQUE-ESTE-SEGREDO-RICKEA-2026"
#define RICK_LICENSE_PRODUCT "RICKEA-MA"
#define RICK_LICENSE_PREFIX  "RMA"

input long     Conta      = 0;             // Conta do cliente (0 = vale em qualquer conta)
input datetime Validade   = D'2026.12.31'; // Ultimo dia valido
input bool     Vitalicia  = false;         // Sem data de validade
input string   Cliente    = "";            // Nome do cliente (so pro registro no CSV)
input bool     SalvarCSV  = true;          // Gravar em MQL5\Files\RickEA_Licencas.csv
//+------------------------------------------------------------------+
string Sha256Hex(const string text)
  {
   uchar src[],dst[],key[];
   int len=StringToCharArray(text,src,0,WHOLE_ARRAY,CP_UTF8);
   if(len>0 && src[len-1]==0) ArrayResize(src,len-1);   // fora o terminador

   if(CryptEncode(CRYPT_HASH_SHA256,src,key,dst)<=0) return("");

   string hex="";
   for(int i=0;i<ArraySize(dst);i++)
      hex+=StringFormat("%02X",dst[i]);
   return(hex);
  }
//+------------------------------------------------------------------+
string LicenseSignature(const string account,const string expiry)
  {
   string payload=RICK_LICENSE_SECRET+"|"+RICK_LICENSE_PRODUCT+"|"+account+"|"+expiry;
   string hash=Sha256Hex(payload);
   if(StringLen(hash)<16) return("");
   return(StringSubstr(hash,0,16));
  }
//+------------------------------------------------------------------+
string MakeKey(const string account,const string expiry)
  {
   string sig=LicenseSignature(account,expiry);
   if(StringLen(sig)<16) return("");
   return(RICK_LICENSE_PREFIX+"-"+account+"-"+expiry+"-"+
          StringSubstr(sig,0,4)+"-"+StringSubstr(sig,4,4)+"-"+
          StringSubstr(sig,8,4)+"-"+StringSubstr(sig,12,4));
  }
//+------------------------------------------------------------------+
void OnStart()
  {
   string expiry="00000000";
   string human ="vitalicia";

   if(!Vitalicia)
     {
      MqlDateTime dt;
      TimeToStruct(Validade,dt);
      expiry=StringFormat("%04d%02d%02d",dt.year,dt.mon,dt.day);
      human =StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day);
     }

   string account=(string)Conta;
   string key=MakeKey(account,expiry);

   if(StringLen(key)==0)
     {
      Print("RickEA KeyGen: falha ao calcular o SHA-256.");
      return;
     }

   string alvo=(Conta==0)?"QUALQUER CONTA":("conta "+account);

   Print("=====================================================");
   Print("  RickEA MA - licenca gerada");
   Print("  Cliente : ",(StringLen(Cliente)>0?Cliente:"-"));
   Print("  Alvo    : ",alvo);
   Print("  Validade: ",human);
   Print("  CHAVE   : ",key);
   Print("=====================================================");

   if(SalvarCSV)
     {
      int fh=FileOpen("RickEA_Licencas.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,';');
      if(fh!=INVALID_HANDLE)
        {
         if(FileSize(fh)==0)
            FileWrite(fh,"gerado_em","cliente","conta","validade","chave");
         FileSeek(fh,0,SEEK_END);
         FileWrite(fh,TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES),
                   Cliente,account,human,key);
         FileClose(fh);
         Print("  (registrado em MQL5\\Files\\RickEA_Licencas.csv)");
        }
      else
         Print("RickEA KeyGen: nao consegui gravar o CSV, erro ",GetLastError());
     }

   Alert(key);
  }
//+------------------------------------------------------------------+
