using System;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;

// =====================================================================
//  RickEA X-Trend  —  porte do indicador MT5 (MQL5) para cTrader (cAlgo)
//  Original: SuperTrend/ATR + EMA + painel visual (RichardTrader).
//  Reproduz: cor das velas pela tendência, linha SuperTrend (verde/vermelho),
//  EMA tracejada, níveis Entrada/TP1/TP2/TP3/SL, etiquetas, painel e preço grande.
//
//  COMO USAR NA cTRADER:
//   1. Abra a cTrader → aba "Automate" → New Indicator.
//   2. Apague o código de exemplo e cole ESTE arquivo inteiro.
//   3. Renomeie a classe/arquivo se quiser (mantenha o nome da classe = nome do indicador).
//   4. Build (ícone de martelo). Depois adicione no gráfico como qualquer indicador.
//
//  NOTAS DE DIFERENÇA (MT5 -> cTrader) — leia o README ao lado:
//   • Cor das velas usa Chart.SetBarColor (cTrader 4.1+). Se sua versão não tiver,
//     comente a linha marcada com «SETBARCOLOR».
//   • O painel na cTrader é texto fixo de canto (sem caixa preenchida como no MT5),
//     mas com a mesma informação e cor pela tendência.
//   • Alertas (push/popup/email) foram deixados de fora do indicador — na cTrader
//     alertas ficam melhores num cBot. Dá pra adicionar depois se quiser.
// =====================================================================

namespace cAlgo
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None, AutoRescale = false)]
    public class RickEAXTrend : Indicator
    {
        // ---- Parâmetros (mesmos do MT5) ----
        [Parameter("ATR Period (SuperTrend)", DefaultValue = 10, MinValue = 1)]
        public int AtrPeriod { get; set; }

        [Parameter("ATR Multiplier", DefaultValue = 3.0, MinValue = 0.1)]
        public double AtrMult { get; set; }

        [Parameter("EMA Period", DefaultValue = 50, MinValue = 1)]
        public int EmaPeriod { get; set; }

        [Parameter("Mostrar painel/níveis/preço", DefaultValue = true)]
        public bool ShowVisuals { get; set; }

        [Parameter("Título do painel", DefaultValue = "RICKEA X-TREND")]
        public string Brand { get; set; }

        [Parameter("Valor de 1 ponto no preço ($)", DefaultValue = 1.0)]
        public double PointInDollar { get; set; }

        [Parameter("TP1 (pontos)", DefaultValue = 16)]
        public double TP1pts { get; set; }

        [Parameter("TP2 (pontos)", DefaultValue = 60)]
        public double TP2pts { get; set; }

        [Parameter("TP3 (pontos)", DefaultValue = 120)]
        public double TP3pts { get; set; }

        [Parameter("Stop inicial (pontos)", DefaultValue = 20)]
        public double SLpts { get; set; }

        [Parameter("Passo do trailing (pontos)", DefaultValue = 100)]
        public double TrailStepPts { get; set; }

        [Parameter("Altura das etiquetas (preço)", DefaultValue = 4.0)]
        public double TagHeight { get; set; }

        [Parameter("Largura das etiquetas (barras)", DefaultValue = 18, MinValue = 2)]
        public int TagWidthBars { get; set; }

        [Parameter("Preço grande no canto", DefaultValue = true)]
        public bool BigPrice { get; set; }

        [Parameter("Preço grande muda de cor pela tendência", DefaultValue = true)]
        public bool BigPriceByTrend { get; set; }

        // ---- Saídas (linhas plotadas) ----
        [Output("Trend Up", LineColor = "Lime", Thickness = 2, PlotType = PlotType.Line)]
        public IndicatorDataSeries TrendUp { get; set; }

        [Output("Trend Down", LineColor = "Red", Thickness = 2, PlotType = PlotType.Line)]
        public IndicatorDataSeries TrendDown { get; set; }

        [Output("EMA", LineColor = "Gold", LineStyle = LineStyle.Lines, Thickness = 1)]
        public IndicatorDataSeries Ema { get; set; }

        // ---- Internos ----
        private AverageTrueRange _atr;
        private ExponentialMovingAverage _emaInd;
        private IndicatorDataSeries _upper, _lower, _dir, _trend;
        private const string PFX = "XT_";

        protected override void Initialize()
        {
            _atr = Indicators.AverageTrueRange(AtrPeriod, MovingAverageType.WilderSmoothing); // = iATR do MT5
            _emaInd = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaPeriod);
            _upper = CreateDataSeries();
            _lower = CreateDataSeries();
            _dir = CreateDataSeries();
            _trend = CreateDataSeries();
        }

        public override void Calculate(int i)
        {
            double atr = _atr.Result[i];
            if (double.IsNaN(atr) || i < AtrPeriod)
            {
                _dir[i] = 0;
                return;
            }

            double hl2 = (Bars.HighPrices[i] + Bars.LowPrices[i]) / 2.0;
            double up = hl2 + AtrMult * atr;
            double dn = hl2 - AtrMult * atr;
            double prevDir = i > 0 ? _dir[i - 1] : 0;

            if (i == 0 || double.IsNaN(prevDir) || prevDir == 0)
            {
                _upper[i] = up;
                _lower[i] = dn;
                _dir[i] = Bars.ClosePrices[i] >= hl2 ? 1 : -1;
            }
            else
            {
                _upper[i] = (up < _upper[i - 1] || Bars.ClosePrices[i - 1] > _upper[i - 1]) ? up : _upper[i - 1];
                _lower[i] = (dn > _lower[i - 1] || Bars.ClosePrices[i - 1] < _lower[i - 1]) ? dn : _lower[i - 1];
                double dir = _dir[i - 1];
                if (dir == 1 && Bars.ClosePrices[i] < _lower[i]) dir = -1;
                if (dir == -1 && Bars.ClosePrices[i] > _upper[i]) dir = 1;
                _dir[i] = dir;
            }

            _trend[i] = _dir[i] == 1 ? _lower[i] : _upper[i];

            // linha SuperTrend colorida (duas séries: cima verde / baixo vermelho)
            if (_dir[i] == 1) { TrendUp[i] = _trend[i]; TrendDown[i] = double.NaN; }
            else { TrendDown[i] = _trend[i]; TrendUp[i] = double.NaN; }

            Ema[i] = _emaInd.Result[i];

            // cor das velas pela tendência  «SETBARCOLOR» (comente se sua cTrader não tiver)
            Chart.SetBarColor(i, _dir[i] == 1 ? Color.Lime : Color.Red);

            // desenhos só quando é a última barra (evita redesenhar o histórico todo)
            if (ShowVisuals && IsLastBar)
                DrawTrade(i);
        }

        // ------------------------------------------------------------------
        private string Px(double v) { return v.ToString("F" + Symbol.Digits); }

        private void DrawTrade(int last)
        {
            int curDir = (int)_dir[last];
            if (curDir == 0) return;

            // barra onde a tendência virou
            int sig = last;
            while (sig > 1 && _dir[sig - 1] == curDir) sig--;

            double P = PointInDollar;
            double entry = Bars.ClosePrices[sig];
            double px = Symbol.Bid > 0 ? Symbol.Bid : Bars.ClosePrices[last];

            double tp1 = entry + curDir * TP1pts * P;
            double tp2 = entry + curDir * TP2pts * P;
            double tp3 = entry + curDir * TP3pts * P;

            // SL com trailing (display): inicial oposto; ao passar TP1 -> BE + passos
            double sl = entry - curDir * SLpts * P;
            double favor = curDir * (px - entry);
            double step = TrailStepPts * P;
            if (favor >= TP1pts * P && step > 0)
            {
                int steps = (int)Math.Floor((favor - TP1pts * P) / step);
                sl = entry + curDir * steps * step; // steps=0 => BE (entrada)
            }

            int xEnd = last + TagWidthBars; // projeta as linhas à direita
            string word = curDir == 1 ? "BUY" : "SELL";

            // segmentos (da virada até a direita)
            Line("ENTRY", entry, Color.DodgerBlue, LineStyle.DotsRare, 1, sig, xEnd);
            Line("SL", sl, Color.Red, LineStyle.DotsRare, 2, sig, xEnd);
            Line("TP1", tp1, Color.Yellow, LineStyle.Solid, 2, sig, xEnd);
            Line("TP2", tp2, Color.Yellow, LineStyle.Solid, 2, sig, xEnd);
            Line("TP3", tp3, Color.Gold, LineStyle.Solid, 1, sig, xEnd);

            // etiquetas (caixa preenchida + texto) à direita
            Tag("ENTRY", entry, Color.DodgerBlue, Color.White, last, " " + word + " @ " + Px(entry));
            Tag("SL", sl, Color.Red, Color.White, last, " SL @ " + Px(sl));
            Tag("TP1", tp1, Color.Yellow, Color.Black, last, " TP1 @ " + Px(tp1));
            Tag("TP2", tp2, Color.Yellow, Color.Black, last, " TP2 @ " + Px(tp2));
            Tag("TP3", tp3, Color.Gold, Color.Black, last, " TP3 @ " + Px(tp3));

            // painel + preço grande
            int mins = (int)((Server.Time - Bars.OpenTimes[sig]).TotalMinutes);
            double pnl = favor / P;
            DrawPanel(curDir, entry, tp1, tp2, tp3, sl, word, mins, pnl);

            if (BigPrice) DrawBigPrice(curDir, px);
        }

        private void Line(string id, double price, Color clr, LineStyle style, int width, int x1, int x2)
        {
            Chart.DrawTrendLine(PFX + "L_" + id, x1, price, x2, price, clr, width, style);
        }

        private void Tag(string id, double price, Color bg, Color fg, int last, string text)
        {
            int xA = last + 1;
            int xB = last + TagWidthBars;
            double h = TagHeight / 2.0;
            var rect = Chart.DrawRectangle(PFX + "BOX_" + id, xA, price + h, xB, price - h, bg, 1);
            rect.IsFilled = true;
            rect.Color = bg;
            var t = Chart.DrawText(PFX + "TXT_" + id, text, xA, price, fg);
            t.HorizontalAlignment = HorizontalAlignment.Left;
            t.VerticalAlignment = VerticalAlignment.Center;
            t.IsBold = true;
        }

        private void DrawBigPrice(int dir, double px)
        {
            Color clr = BigPriceByTrend ? (dir == 1 ? Color.Lime : Color.Red) : Color.Yellow;
            var t = Chart.DrawStaticText(PFX + "BIGPX", "  " + Px(px) + "  ",
                                         VerticalAlignment.Top, HorizontalAlignment.Right, clr);
        }

        private void DrawPanel(int dir, double entry, double tp1, double tp2, double tp3,
                               double sl, string word, int mins, double pnl)
        {
            Color accent = dir == 1 ? Color.Lime : Color.Red;
            string txt =
                Brand + "\n" +
                "Trend signal: " + word + " @ " + Px(entry) + "\n" +
                "Last " + word + " signal came " + mins + " minutes ago\n" +
                "     Target 1: " + Px(tp1) + "\n" +
                "     Target 2: " + Px(tp2) + "\n" +
                "     Target 3: " + Px(tp3) + "\n" +
                "Stop loss: " + Px(sl) + "\n" +
                "Current P&L: " + pnl.ToString("F2") + " points";
            Chart.DrawStaticText(PFX + "PANEL", txt,
                                 VerticalAlignment.Bottom, HorizontalAlignment.Left, accent);
        }
    }
}
