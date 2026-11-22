# 配音自检

配音是机器合成的，没人能把两千多句一句一句听完。这一套脚本把录好的 mp3 "听"回来，和要读的字对一遍，
专门找**读错的字**（主要是多音字）、漏读、符号和数字读错。查出来的问题在 `build_manifest.py` 和
`extra_<游戏>.json` 里换同音字，再重录那几句。

什么时候跑：加了新游戏 / 一大批新台词以后；换了声音或者 TTS 版本以后。

## 四道检查

| 查什么 | 怎么查 | 脚本 |
|---|---|---|
| 漏读、多读、符号和数字（中文 + 英文） | Whisper 把声音转成字，按不带调的拼音（英文按词）和原文比 | `whisper_run.py` `whisper_cmp.py` `whisper_cmp_en.py` |
| 声母韵母不同的多音字（长 cháng / zhǎng） | 强制对齐（MFA）：词典里每个字把几种读音都列上，看对齐器挑了哪一种 | `build_dict.py` `analyze.py` |
| 只差声调的多音字（数 shǔ / shù） | 量音高曲线，用这套配音里两万多个单音字训练一个声调分类器，再去判多音字 | `f0.py` `tone.py` `tone_judge.py` |
| 上面三道的嫌疑 + 全部多音字普查 | **同音字对照**：把这个字换成"读音甲"的同音字、"读音乙"的同音字各合成一遍，看原录音在这个字上和哪一版一样 | `poly.py` `census.py` `mkcases.py` `synth.py` `abcmp.py` `census_judge.py` `judge3.py` |

为什么要四道：普通的语音识别对多音字没用——不管读成哪个音，它写出来都是同一个字。对齐器分得清声母韵母，
分不清声调。声调分类器只管声调，而且虚词（和、把、好）读得轻的时候会判错。同音字对照最可靠
（同一个声音、同一句话，读法一样的话两段录音几乎一模一样），但要联网合成，而且换了字有时候会带偏语调。
所以：前三道出嫌疑，第四道定案；两道以上说法一致的才算数，最后人看一眼上下文该读什么。

## 环境

三个环境，都装在工程外面（脚本不依赖位置）：

- **识别**：Python 3 + `torch transformers pypinyin soundfile`（Whisper large-v3-turbo，Apple 芯片上用 MPS）。
- **对齐和音高**：Montreal Forced Aligner 3（conda-forge 的 `montreal-forced-aligner`），模型
  `mfa model download acoustic mandarin_mfa`、`mfa model download dictionary mandarin_china_mfa`。
  环境里自带 librosa / scikit-learn。音高用 `f0.py` 里自己写的自相关法——librosa 的 `pyin` 在这个环境里会崩。
- **合成对照句**：`generate_voice.py` 用的那个 edge-tts 环境（`/tmp/mandarin-tts-env`），同一个声音、同一个语速。

装这些东西**不要动系统的 Homebrew**（2026-11 那次 `brew install micromamba` 连带升级了 simdjson，把 Node 弄坏了）。
用 micromamba 的独立二进制，或者已有的 conda。

## 步骤

`W` 是随便一个工作目录，`R` 是工程根目录。

```sh
# 1 Whisper（中文约 15 分钟，英文约 20 分钟）
python whisper_run.py $R/tools/voice/manifest.json    $R/RanranGame/Voice   zh $W/whisper_zh.json
python whisper_run.py $R/tools/voice/manifest_en.json $R/RanranGame/VoiceEN en $W/whisper_en.json
python whisper_cmp.py    $R/tools/voice/manifest.json    $W/whisper_zh.json
python whisper_cmp_en.py $R/tools/voice/manifest_en.json $W/whisper_en.json

# 2 对齐：一个字一个词的词典 + 文本，mp3 转成 16k 的 wav 放进 $W/mfa/corpus/xiaoxiao/
python build_dict.py $R/tools/voice/manifest.json <mandarin_china_mfa.dict> $W/mfa
mfa align $W/mfa/corpus $W/mfa/chars.dict mandarin_mfa $W/mfa/out --clean --no_tokenization --output_format json --beam 100 --retry_beam 400
python analyze.py $W/mfa            # segment 那一类才有用；tone 那一类全是噪声，别看

# 3 声调
python f0.py $W/mfa/corpus/xiaoxiao $W/f0
python poly.py $W/mfa/expected.json $W/poly.json
python tone.py $W/mfa $W/f0 $W/poly.json $W/tone_pred.json     # 先看打印出来的交叉验证正确率（这一次 90%）
python tone_judge.py $W/tone_pred.json $W/poly.json $W/mfa/expected.json

# 4 同音字对照
python census.py $W/mfa/expected.json $W/poly.json $W/census.json $W/census_groups.json
ONLY_A=1 python mkcases.py $W/mfa $W/census.json $W/census      # 普查：每组只合成"读成另一个音"的那一版
python synth.py $W/census_jobs.json $W/caudio                    # 约 1900 句，20 分钟
python f0.py $W/caudio $W/cf0
python abcmp.py $W/census_cases.json $W/caudio $W/mfa/corpus/xiaoxiao $W/f0 $W/cf0
python census_judge.py $W/census_cases.json $W/census_cases_result.json $W/census_groups.json
# 嫌疑（上面几步打印出来的）写成 [[句子, 第几个字, 该读的音, 另一个读音], ...]，三方对照定案：
python mkcases.py $W/mfa suspects.json $W/r2 && python synth.py $W/r2_jobs.json $W/r2audio && python f0.py $W/r2audio $W/r2f0
python abcmp.py $W/r2_cases.json $W/r2audio $W/mfa/corpus/xiaoxiao $W/f0 $W/r2f0
python judge3.py $W/r2_cases.json $W/r2_cases_result.json
```

`judge3.py` 每行三个数：原录音和"重新合成的原句""读音甲那一版""读音乙那一版"在这个字上差多少（越小越像）。
哪一版和第一个数差不多，实际读的就是哪个音；两版都差得远，说明换字带偏了语调，这一条定不了，看声调分类器。

## 怎么改

读错的在 `build_manifest.py`（五子棋 / 象棋 / 围棋的 `*_spoken`）或者 `extra_<游戏>.json` 的 `replace` 里换同音字
（抽将 → 抽江），断错词的加一个逗号（下都只能 → 下，都只能）。只改 `speak`，屏幕上显示的字不动。
改完 `python3 tools/voice/build_manifest.py`，让 Codex 跑 `generate_voice.py` 重录，再把重录的句子按上面查一遍。

## 查不出来的

- 参考读音是 pypinyin 按上下文给的，它也会错。它错、TTS 对的时候会被当成嫌疑（一看就知道）；
  **它和 TTS 错成一样**的时候查不出来，除非 Whisper 正好听成了别的字（"往还空着"就是这样逮到的）。
- 普查按"前后各一个字"归组，每组只听一句。同一个词在别的句子里读法不同的话会漏。
- 不是多音字的字读错（很少见）只有 Whisper 这一道。
- 读得对不对之外的事——语气、停顿、好不好听——不在这里。

## 2026-11 这一次的结果

中文 2121 句、英文 3796 句。英文没有问题。中文没有漏读；多音字读错 9 类 26 句，都已换字重录并复查过（复查时发现"解江成功"被当成姓解的解读成 xiè，又改成"姐江成功"）：
抽将 / 解将（jiàng → jiāng）、"将军、解将和将死"的解（xiè）、塞象眼（sè）、往还空着（huán）、
句首的"冲四"（chòng）、"冲四只有"（四只 zhī）、"下都只能 / 逃都只有"（dū）、别把子（bà）、两种花（zhòng）。
