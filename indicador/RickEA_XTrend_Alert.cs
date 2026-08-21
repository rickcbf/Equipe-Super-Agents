using System;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

// =====================================================================
//  RickEA X-Trend ALERT  —  cBot de alerta de virada (cTrader / cAlgo)
//  Usa a MESMA lógica SuperTrend/ATR do indicador RickEA X-Trend, mas:
//   • roda só na BARRA FECHADA (OnBar) -> NÃO repinta, alerta confiável;
//   • NÃO envia ordens, NÃO opera a conta -> é só um "vigia" de sinal;
//   • quando a tendência VIRA (BUY<->SELL) ele avisa:
//       - som (arquivo .wav opcional),
//       - texto grande no gráfico (verde/vermelho),
//       - linha no LOG (aba Log do cBot),
//       - e-mail opcional (precisa configurar SMTP em cTrader > Settings > Email).
//
//  COMO USAR:
//   1. cTrader > aba "Automate" > New cBot.
//   2. Apague o exemplo e cole ESTE arquivo inteiro > Build (martelo).
//   3. Abra o gráfico desejado (ex.: XAUUSD) > adicione o cBot "RickEA X-Trend Alert".
//   4. Ajuste os parâmetros (mesmos do indicador: ATR 10 / Mult 3.0) e clique PLAY.
//   Deixe o cBot rodando na aba Automate; ele avisa a cada virada de tendência.
//
//  OBS. sobre PUSH no celular: a API de cBot da cTrader NÃO tem push direto pro
//  app do celular. O caminho que funciona é o E-MAIL (ative "Enviar e-mail" e
//  configure o SMTP nas Settings da cTrader). Aí é só deixar seu e-mail com
//  notificação no celular. Som + texto no gráfico funcionam sem configurar nada.
// =====================================================================

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None, TimeZone = TimeZones.UTC, AddIndicators = true)]
    public class RickEAXTrendAlert : Robot
    {
        // ---- Parâmetros (iguais ao indicador) ----
        [Parameter("ATR Period (SuperTrend)", DefaultValue = 10, MinValue = 1)]
        public int AtrPeriod { get; set; }

        [Parameter("ATR Multiplier", DefaultValue = 3.0, MinValue = 0.1)]
        public double AtrMult { get; set; }

        // ---- Como avisar ----
        [Parameter("Tocar som na virada", DefaultValue = true, Group = "Alerta")]
        public bool UseSound { get; set; }

        [Parameter("Arquivo de som .wav (opcional)", DefaultValue = "", Group = "Alerta")]
        public string SoundFile { get; set; }

        [Parameter("Mostrar aviso no gráfico", DefaultValue = true, Group = "Alerta")]
        public bool ShowOnChart { get; set; }

        [Parameter("Enviar e-mail", DefaultValue = false, Group = "E-mail (precisa SMTP nas Settings)")]
        public bool UseEmail { get; set; }

        [Parameter("E-mail de origem", DefaultValue = "", Group = "E-mail (precisa SMTP nas Settings)")]
        public string EmailFrom { get; set; }

        [Parameter("E-mail de destino", DefaultValue = "", Group = "E-mail (precisa SMTP nas Settings)")]
        public string EmailTo { get; set; }

        // ---- Internos ----
        private AverageTrueRange _atr;
        private double _up, _dn;   // bandas trailing
        private int _dir;          // 1 = alta, -1 = baixa
        private bool _init;

        protected override void OnStart()
        {
            _atr = Indicators.AverageTrueRange(AtrPeriod, MovingAverageType.WilderSmoothing); // = iATR do MT5
            Print("RickEA X-Trend Alert iniciado em {0} {1}. Aguardando viradas...", SymbolName, TimeFrame);
        }

        // OnBar dispara quando UMA barra FECHA -> usamos a última fechada (sem repaint).
        protected override void OnBar()
        {
            int i = Bars.Count - 2; // índice da última barra JÁ FECHADA
            if (i < AtrPeriod) return;

            double atr = _atr.Result[i];
            if (double.IsNaN(atr)) return;

            double hl2 = (Bars.HighPrices[i] + Bars.LowPrices[i]) / 2.0;
            double up = hl2 + AtrMult * atr;
            double dn = hl2 - AtrMult * atr;

            if (!_init)
            {
                _up = up;
                _dn = dn;
                _dir = Bars.ClosePrices[i] >= hl2 ? 1 : -1;
                _init = true;
                return; // primeira barra só inicializa, não alerta
            }

            double prevClose = Bars.ClosePrices[i - 1];
            _up = (up < _up || prevClose > _up) ? up : _up;
            _dn = (dn > _dn || prevClose < _dn) ? dn : _dn;

            int newDir = _dir;
            if (_dir == 1 && Bars.ClosePrices[i] < _dn) newDir = -1;
            if (_dir == -1 && Bars.ClosePrices[i] > _up) newDir = 1;

            if (newDir != _dir)
            {
                _dir = newDir;
                Fire(newDir, Bars.ClosePrices[i]);
            }
        }

        private void Fire(int dir, double price)
        {
            string word = dir == 1 ? "BUY" : "SELL";
            string px = price.ToString("F" + Symbol.Digits);
            string msg = "RickEA X-Trend • " + SymbolName + " " + TimeFrame + " • VIRADA " + word + " @ " + px;

            // 1) LOG (aba Log do cBot)
            Print(msg);

            // 2) aviso grande no gráfico
            if (ShowOnChart)
            {
                Color clr = dir == 1 ? Color.Lime : Color.Red;
                var t = Chart.DrawStaticText("XT_ALERT",
                    "\n  >> " + word + " <<  @ " + px + "\n  " + Server.Time.ToString("dd/MM HH:mm") + "  ",
                    VerticalAlignment.Top, HorizontalAlignment.Center, clr);
                t.Color = clr;
            }

            // 3) som (só se você indicar um .wav)
            if (UseSound && !string.IsNullOrEmpty(SoundFile))
            {
                try { Notifications.PlaySound(SoundFile); }
                catch (Exception e) { Print("Falha ao tocar som: {0}", e.Message); }
            }

            // 4) e-mail (precisa SMTP configurado em cTrader > Settings > Email)
            if (UseEmail && !string.IsNullOrEmpty(EmailFrom) && !string.IsNullOrEmpty(EmailTo))
            {
                try { Notifications.SendEmail(EmailFrom, EmailTo, "RickEA X-Trend: virada " + word, msg); }
                catch (Exception e) { Print("Falha ao enviar e-mail: {0}", e.Message); }
            }
        }
    }
}
