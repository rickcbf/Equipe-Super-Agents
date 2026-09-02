using System;
using cAlgo.API;
using cAlgo.API.Internals;

// =====================================================================
//  RickEA Statistics  —  indicador de ESTATÍSTICA e PROBABILIDADE (cTrader / cAlgo)
//  -------------------------------------------------------------------
//  Painel visual que lê um RANGE de N velas fechadas (ajustável) e mostra,
//  TUDO calculado DENTRO desse range:
//    • Cor predominante do momento (painel VERDE se predomina alta / VERMELHO se baixa).
//    • Campos BUY e SELL — o que PREDOMINA fica EM CIMA — com a QUANTIDADE de velas
//      e o PERCENTUAL ao lado.
//    • Tamanho do RANGE (maior máxima − menor mínima) em pips.
//    • MEDIA de pips do range (amplitude media por vela).
//    • Pips da ULTIMA vela encerrada.
//    • Soma de pips de BUY (verde) e soma de pips de SELL (vermelho).
//    • Preço do ativo GRANDE, no canto superior direito, ACIMA do painel.
//    • BARRA horizontal (largura do painel) verde/vermelha preenchida pelo PERCENTUAL
//      de cada lado = probabilidade do momento a partir dos dados das velas.
//    • MAIOR sequencia seguida de velas BUY e de velas SELL dentro do range.
//
//  COMO USAR NA cTRADER:
//   1. cTrader → aba "Automate" → New Indicator.
//   2. Apague o código de exemplo e cole ESTE arquivo inteiro.
//   3. Build (martelo). Depois adicione no gráfico como qualquer indicador.
//
//  Definição de vela (padrão): BUY = fechamento > abertura ; SELL = fechamento < abertura.
//  Vela "doji" (fecha = abre) é neutra e não conta para BUY nem SELL.
//  Os percentuais usam BUY+SELL como base (as neutras ficam de fora).
// =====================================================================

namespace cAlgo
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None, AutoRescale = false)]
    public class RickEAStatistics : Indicator
    {
        // ---------------------- Parâmetros ----------------------
        [Parameter("Range (qtd. de velas)", DefaultValue = 20, MinValue = 2, MaxValue = 5000, Group = "Cálculo")]
        public int RangeCandles { get; set; }

        [Parameter("Título do painel", DefaultValue = "RICKEA STATISTICS", Group = "Aparência")]
        public string Brand { get; set; }

        [Parameter("Mostrar preço grande", DefaultValue = true, Group = "Aparência")]
        public bool ShowBigPrice { get; set; }

        [Parameter("Tamanho da fonte do preço", DefaultValue = 34, MinValue = 12, MaxValue = 80, Group = "Aparência")]
        public int BigPriceFontSize { get; set; }

        [Parameter("Posição (horizontal)", DefaultValue = HorizontalAlignment.Right, Group = "Aparência")]
        public HorizontalAlignment PanelHAlign { get; set; }

        [Parameter("Posição (vertical)", DefaultValue = VerticalAlignment.Top, Group = "Aparência")]
        public VerticalAlignment PanelVAlign { get; set; }

        // ---------------------- Paleta ----------------------
        private static readonly Color GreenBright = Color.FromArgb(255, 22, 199, 132);   // #16C784
        private static readonly Color RedBright = Color.FromArgb(255, 234, 57, 67);      // #EA3943
        private static readonly Color GreenBg = Color.FromArgb(235, 10, 46, 32);
        private static readonly Color RedBg = Color.FromArgb(235, 48, 14, 16);
        private static readonly Color NeutralBg = Color.FromArgb(235, 18, 22, 30);
        private static readonly Color TextDim = Color.FromArgb(255, 176, 190, 197);
        private static readonly Color TextWhite = Color.FromArgb(255, 240, 244, 248);
        private static readonly Color CardBg = Color.FromArgb(60, 0, 0, 0);

        // ---------------------- Controles (referências para atualizar) ----------------------
        private Border _root;             // caixa do painel (muda de cor pela predominância)
        private TextBlock _bigPrice;      // preço grande acima do painel
        private TextBlock _headTitle;     // marca
        private TextBlock _headDir;       // "ALTA" / "BAIXA"

        // linha de cima e de baixo (a predominante vai para cima)
        private TextBlock _topLabel, _topCount, _topPct;
        private TextBlock _botLabel, _botCount, _botPct;

        // barra de probabilidade
        private Grid _bar;
        private Border _barBuy, _barSell;
        private TextBlock _barBuyTxt, _barSellTxt;

        // valores estatísticos
        private TextBlock _valRange, _valAvg, _valLast, _valBuyPips, _valSellPips, _valBuyStreak, _valSellStreak, _valSample;

        private bool _built;

        protected override void Initialize()
        {
            BuildPanel();
        }

        public override void Calculate(int index)
        {
            // atualiza o preço a cada tick (última barra)
            if (!IsLastBar)
                return;

            if (ShowBigPrice && _bigPrice != null)
            {
                double px = Symbol.Bid > 0 ? Symbol.Bid : Bars.ClosePrices[index];
                _bigPrice.Text = Px(px);
                _bigPrice.IsVisible = true;
            }
            else if (_bigPrice != null)
            {
                _bigPrice.IsVisible = false;
            }

            // ---- range = últimas N velas FECHADAS (exclui a que está se formando) ----
            int end = index - 1;                       // última vela encerrada
            if (end < 1)
                return;
            int start = end - RangeCandles + 1;
            if (start < 0)
                start = 0;
            int sample = end - start + 1;              // qtd. real de velas usadas

            int buyCount = 0, sellCount = 0;
            double buyPips = 0, sellPips = 0;
            double sumAmpl = 0;
            double maxHigh = double.MinValue, minLow = double.MaxValue;
            int curBuyRun = 0, curSellRun = 0, maxBuyRun = 0, maxSellRun = 0;

            for (int i = start; i <= end; i++)
            {
                double o = Bars.OpenPrices[i];
                double c = Bars.ClosePrices[i];
                double h = Bars.HighPrices[i];
                double l = Bars.LowPrices[i];

                if (h > maxHigh) maxHigh = h;
                if (l < minLow) minLow = l;
                sumAmpl += (h - l);

                if (c > o)          // vela BUY
                {
                    buyCount++;
                    buyPips += (c - o);
                    curBuyRun++;
                    curSellRun = 0;
                    if (curBuyRun > maxBuyRun) maxBuyRun = curBuyRun;
                }
                else if (c < o)     // vela SELL
                {
                    sellCount++;
                    sellPips += (o - c);
                    curSellRun++;
                    curBuyRun = 0;
                    if (curSellRun > maxSellRun) maxSellRun = curSellRun;
                }
                else                // doji / neutra
                {
                    curBuyRun = 0;
                    curSellRun = 0;
                }
            }

            double pip = Symbol.PipSize > 0 ? Symbol.PipSize : Symbol.TickSize;
            double rangePips = (maxHigh - minLow) / pip;
            double avgPips = (sumAmpl / sample) / pip;
            double buyPipsN = buyPips / pip;
            double sellPipsN = sellPips / pip;

            // pips da última vela encerrada (amplitude) + direção
            double lastO = Bars.OpenPrices[end];
            double lastC = Bars.ClosePrices[end];
            double lastPips = (Bars.HighPrices[end] - Bars.LowPrices[end]) / pip;
            int lastDir = lastC > lastO ? 1 : (lastC < lastO ? -1 : 0);

            // percentuais (base = BUY + SELL)
            int decisive = buyCount + sellCount;
            double buyPct = decisive > 0 ? 100.0 * buyCount / decisive : 50.0;
            double sellPct = decisive > 0 ? 100.0 * sellCount / decisive : 50.0;
            bool buyDominant = buyCount >= sellCount;

            UpdatePanel(buyDominant, buyCount, sellCount, buyPct, sellPct,
                        rangePips, avgPips, lastPips, lastDir,
                        buyPipsN, sellPipsN, maxBuyRun, maxSellRun, sample);
        }

        // =================================================================
        //  Construção do painel (uma vez)
        // =================================================================
        private void BuildPanel()
        {
            if (_built) return;

            // Coluna externa: preço grande (em cima) + painel (embaixo), ancorada no canto escolhido.
            var outer = new StackPanel
            {
                Orientation = Orientation.Vertical,
                HorizontalAlignment = PanelHAlign,
                VerticalAlignment = PanelVAlign,
                Margin = new Thickness(12)
            };

            _bigPrice = new TextBlock
            {
                Text = "—",
                FontSize = BigPriceFontSize,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Thickness(0, 0, 4, 6)
            };
            outer.AddChild(_bigPrice);

            var inner = new StackPanel { Orientation = Orientation.Vertical, Width = 268 };

            // --- cabeçalho ---
            var header = new Grid(1, 2) { Margin = new Thickness(0, 0, 0, 8) };
            _headTitle = new TextBlock
            {
                Text = Brand,
                FontSize = 13,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                VerticalAlignment = VerticalAlignment.Center
            };
            _headDir = new TextBlock
            {
                Text = "—",
                FontSize = 12,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            header.AddChild(_headTitle, 0, 0);
            header.AddChild(_headDir, 0, 1);
            inner.AddChild(header);

            // --- linha de cima (predominante) e de baixo ---
            inner.AddChild(BuildDirRow(out _topLabel, out _topCount, out _topPct, 15));
            inner.AddChild(BuildDirRow(out _botLabel, out _botCount, out _botPct, 15));

            // --- barra de probabilidade (largura do painel) ---
            _bar = new Grid(1, 2)
            {
                Height = 26,
                Margin = new Thickness(0, 8, 0, 8)
            };
            _barBuy = new Border { BackgroundColor = GreenBright };
            _barSell = new Border { BackgroundColor = RedBright };
            _barBuyTxt = new TextBlock
            {
                Text = "50%",
                FontSize = 12,
                FontWeight = FontWeight.Bold,
                ForegroundColor = Color.White,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            _barSellTxt = new TextBlock
            {
                Text = "50%",
                FontSize = 12,
                FontWeight = FontWeight.Bold,
                ForegroundColor = Color.White,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            _barBuy.Child = _barBuyTxt;
            _barSell.Child = _barSellTxt;
            _bar.AddChild(_barBuy, 0, 0);
            _bar.AddChild(_barSell, 0, 1);
            inner.AddChild(_bar);

            // --- grade de estatísticas ---
            var stats = new StackPanel { Orientation = Orientation.Vertical };
            stats.AddChild(StatRow("Range (pips)", out _valRange, TextDim));
            stats.AddChild(StatRow("Média pips/vela", out _valAvg, TextDim));
            stats.AddChild(StatRow("Última vela (pips)", out _valLast, TextDim));
            stats.AddChild(StatRow("Pips BUY", out _valBuyPips, GreenBright));
            stats.AddChild(StatRow("Pips SELL", out _valSellPips, RedBright));
            stats.AddChild(StatRow("Maior seq. BUY", out _valBuyStreak, GreenBright));
            stats.AddChild(StatRow("Maior seq. SELL", out _valSellStreak, RedBright));
            stats.AddChild(StatRow("Velas no range", out _valSample, TextDim));
            inner.AddChild(stats);

            _root = new Border
            {
                BackgroundColor = NeutralBg,
                BorderColor = Color.FromArgb(255, 60, 70, 85),
                BorderThickness = new Thickness(1.5),
                CornerRadius = 8,
                Padding = new Thickness(12),
                Child = inner
            };
            outer.AddChild(_root);

            Chart.AddControl(outer);
            _built = true;
        }

        // linha BUY/SELL: [ label ] [ count ] [ pct à direita ]
        private Grid BuildDirRow(out TextBlock label, out TextBlock count, out TextBlock pct, int fontSize)
        {
            var row = new Grid(1, 3) { Margin = new Thickness(0, 2, 0, 2) };
            row.Columns[0].SetWidthInStars(1.4);
            row.Columns[1].SetWidthInStars(1.0);
            row.Columns[2].SetWidthInStars(1.0);

            label = new TextBlock
            {
                Text = "—",
                FontSize = fontSize,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                VerticalAlignment = VerticalAlignment.Center
            };
            count = new TextBlock
            {
                Text = "0",
                FontSize = fontSize - 1,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            pct = new TextBlock
            {
                Text = "0%",
                FontSize = fontSize,
                FontWeight = FontWeight.Bold,
                ForegroundColor = TextWhite,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            row.AddChild(label, 0, 0);
            row.AddChild(count, 0, 1);
            row.AddChild(pct, 0, 2);
            return row;
        }

        // linha de estatística: [ rótulo ....... valor ]
        private Grid StatRow(string caption, out TextBlock value, Color valueColor)
        {
            var row = new Grid(1, 2) { Margin = new Thickness(0, 2, 0, 2) };
            var cap = new TextBlock
            {
                Text = caption,
                FontSize = 12,
                ForegroundColor = TextDim,
                VerticalAlignment = VerticalAlignment.Center
            };
            value = new TextBlock
            {
                Text = "—",
                FontSize = 12,
                FontWeight = FontWeight.Bold,
                ForegroundColor = valueColor,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            row.AddChild(cap, 0, 0);
            row.AddChild(value, 0, 1);
            return row;
        }

        // =================================================================
        //  Atualização do painel (a cada tick na última barra)
        // =================================================================
        private void UpdatePanel(bool buyDominant, int buyCount, int sellCount, double buyPct, double sellPct,
                                 double rangePips, double avgPips, double lastPips, int lastDir,
                                 double buyPipsN, double sellPipsN, int maxBuyRun, int maxSellRun, int sample)
        {
            // cor predominante do painel
            _root.BackgroundColor = buyDominant ? GreenBg : RedBg;
            _root.BorderColor = buyDominant ? GreenBright : RedBright;

            _headDir.Text = buyDominant ? "▲ ALTA" : "▼ BAIXA";
            _headDir.ForegroundColor = buyDominant ? GreenBright : RedBright;

            // o predominante vai para a linha de CIMA
            if (buyDominant)
            {
                SetDirRow(_topLabel, _topCount, _topPct, "BUY", buyCount, buyPct, GreenBright);
                SetDirRow(_botLabel, _botCount, _botPct, "SELL", sellCount, sellPct, RedBright);
            }
            else
            {
                SetDirRow(_topLabel, _topCount, _topPct, "SELL", sellCount, sellPct, RedBright);
                SetDirRow(_botLabel, _botCount, _botPct, "BUY", buyCount, buyPct, GreenBright);
            }

            // barra de probabilidade: larguras proporcionais aos percentuais
            _bar.Columns[0].SetWidthInStars(Math.Max(buyPct, 0.0001));
            _bar.Columns[1].SetWidthInStars(Math.Max(sellPct, 0.0001));
            _barBuyTxt.Text = buyPct >= 12 ? buyPct.ToString("F0") + "%" : "";
            _barSellTxt.Text = sellPct >= 12 ? sellPct.ToString("F0") + "%" : "";

            // estatísticas
            _valRange.Text = rangePips.ToString("F1");
            _valAvg.Text = avgPips.ToString("F1");

            _valLast.Text = (lastDir >= 0 ? "+" : "-") + lastPips.ToString("F1");
            _valLast.ForegroundColor = lastDir > 0 ? GreenBright : (lastDir < 0 ? RedBright : TextDim);

            _valBuyPips.Text = "+" + buyPipsN.ToString("F1");
            _valSellPips.Text = "-" + sellPipsN.ToString("F1");
            _valBuyStreak.Text = maxBuyRun.ToString();
            _valSellStreak.Text = maxSellRun.ToString();
            _valSample.Text = sample.ToString();
        }

        private void SetDirRow(TextBlock label, TextBlock count, TextBlock pct,
                               string word, int candles, double percent, Color color)
        {
            label.Text = word;
            label.ForegroundColor = color;
            count.Text = candles + (candles == 1 ? " vela" : " velas");
            count.ForegroundColor = color;
            pct.Text = percent.ToString("F0") + "%";
            pct.ForegroundColor = color;
        }

        private string Px(double v)
        {
            return v.ToString("F" + Symbol.Digits);
        }
    }
}
