{include file="sections/header.tpl"}

<div class="row">
    <div class="col-sm-12 col-md-12">
        <div class="panel panel-primary panel-hovered panel-stacked mb30">
            <div class="panel-heading">DOKU Payment Gateway Settings (QRIS & All Channels)</div>
            <div class="panel-body">
                <form class="form-horizontal" method="post" role="form" action="{$_url}services/paymentgateway-save">
                    <input type="hidden" name="gateway" value="doku">
                    
                    <div class="form-group">
                        <label class="col-md-3 control-label">DOKU Client ID / Mall ID</label>
                        <div class="col-md-7">
                            <input type="text" class="form-control" id="doku_client_id" name="doku_client_id" value="{$doku_client_id}" placeholder="Contoh: MCH-12345-XXXXX" required>
                            <p class="help-block">Client ID didapatkan dari Dashboard DOKU Merchant.</p>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="col-md-3 control-label">DOKU Secret Key / Shared Key</label>
                        <div class="col-md-7">
                            <input type="password" class="form-control" id="doku_secret_key" name="doku_secret_key" value="{$doku_secret_key}" placeholder="Secret Key HMAC-SHA256" required>
                            <p class="help-block">Secret Key / Shared Key DOKU.</p>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="col-md-3 control-label">Environment Mode</label>
                        <div class="col-md-7">
                            <select class="form-control" id="doku_mode" name="doku_mode">
                                <option value="sandbox" {if $doku_mode eq 'sandbox'}selected{/if}>Sandbox (Testing)</option>
                                <option value="production" {if $doku_mode eq 'production'}selected{/if}>Production (Live Pembayaran Nyata)</option>
                            </select>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="col-md-3 control-label">Masa Berlaku Pembayaran (Menit)</label>
                        <div class="col-md-7">
                            <input type="number" class="form-control" id="doku_expired_time" name="doku_expired_time" value="{$doku_expired_time}" placeholder="60">
                            <p class="help-block">Waktu tunggu sebelum QRIS / Tagihan kedaluwarsa (default 60 menit).</p>
                        </div>
                    </div>

                    <div class="form-group">
                        <label class="col-md-3 control-label">Notification / Webhook URL</label>
                        <div class="col-md-7">
                            <input type="text" class="form-control" readonly value="{$_url}callback/doku">
                            <p class="help-block text-warning"><i class="fa fa-info-circle"></i> Pasang URL ini di <b>DOKU Merchant Dashboard -> Notification URL</b>.</p>
                        </div>
                    </div>

                    <div class="form-group">
                        <div class="col-lg-offset-3 col-lg-7">
                            <button class="btn btn-primary waves-effect waves-light" type="submit">Simpan Konfigurasi</button>
                            <a href="{$_url}services/paymentgateway" class="btn btn-default waves-effect">Kembali</a>
                        </div>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

{include file="sections/footer.tpl"}
