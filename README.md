# パーリ仏典 多読用 AI ノート

本リポジトリにはパーリ仏典の翻訳や解釈など, AI が生成したテキストが含まれています.
内容の正確性は保証されません. 学習や参考の用途を想定しています.

- パーリ仏典の多読の記録: https://note.com/krhitoshi
- パーリ語で仏典を読み始めた経緯: https://note.com/krhitoshi/n/nb26fcde28e8d

## データソース

パーリ仏典のテキストデータは Vipassana Research Institute の
Chattha Sangayana Tipitaka を使用しています.

- ソース: https://github.com/VipassanaTech/tipitaka-xml
- ライセンス: 非商用利用のための自由配布
- クレジット: Vipassana Research Institute (https://www.tipitaka.org/)

## システムプロンプト

- system_prompt.md (意訳あり)
- system_prompt_no_paraphrase.md (意訳なし)
	- 意訳を出力しないことでトークン消費量と出力のボリュームを抑える

## ディレクトリ構成

- mn 中部経典 (Majjhima-nikāya)
- dhammapada 小部経典 ダンマパダ (Khuddaka-nikāya, Dhammapada)
