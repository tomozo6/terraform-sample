# terraform-sample

Terraform のサンプルコード

![](./assets/diagram.dio.svg)

## 前提条件

- Route53にZONEが設定されていること。

## 実行手順

### locals.tfの編集

- `product` に任意の値を設定する。
- `base_fqdn`にRoute53に登録してあるZONE名を設定する。(例: `"example.com"`)

### Terraformを実行する

```bash
$ cd envs/dev
$ terraform init
$ terraform plan
$ terrafomrm apply
```

### 静的コンテンツを配置

作成されたS3(`${local.product}-${local.env}-web-s3`)に、確認用の静的コンテンツを配置する。</br>
マネコンで手動でドラッグ&ドロップで構わない。
