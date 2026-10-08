<?php
/**
 * PHPNuxBill Payment Gateway Plugin - DOKU Checkout (Jokul)
 * Compatible with MikroTik RouterOS v7 & RouterOS v6
 * Handles QRIS, Virtual Account, E-Wallet via DOKU Checkout API
 */

function doku_validate_config()
{
    global $config;
    if (empty($config['doku_client_id']) || empty($config['doku_secret_key'])) {
        Message::sendTelegram("DOKU: Client ID atau Secret Key belum dikonfigurasi.");
        r2(U . 'services/paymentgateway', 'e', 'DOKU configuration is incomplete');
    }
}

function doku_show_config()
{
    global $ui, $config;
    $ui->assign('doku_client_id', $config['doku_client_id'] ?? '');
    $ui->assign('doku_secret_key', $config['doku_secret_key'] ?? '');
    $ui->assign('doku_mode', $config['doku_mode'] ?? 'sandbox');
    $ui->assign('doku_expired_time', $config['doku_expired_time'] ?? '60');
    $ui->display('doku_config.tpl');
}

function doku_save_config()
{
    global $admin;
    $doku_client_id = _post('doku_client_id');
    $doku_secret_key = _post('doku_secret_key');
    $doku_mode = _post('doku_mode');
    $doku_expired_time = _post('doku_expired_time', '60');

    $configs = [
        'doku_client_id' => trim($doku_client_id),
        'doku_secret_key' => trim($doku_secret_key),
        'doku_mode' => $doku_mode,
        'doku_expired_time' => trim($doku_expired_time)
    ];

    foreach ($configs as $key => $val) {
        $d = ORM::for_table('tbl_appconfig')->where('setting', $key)->find_one();
        if ($d) {
            $d->value = $val;
            $d->save();
        } else {
            $d = ORM::for_table('tbl_appconfig')->create();
            $d->setting = $key;
            $d->value = $val;
            $d->save();
        }
    }

    _log('[' . $admin['username'] . ']: DOKU Payment Gateway Settings Updated', 'Admin', $admin['id']);
    r2(U . 'services/paymentgateway', 's', 'Settings Saved Successfully');
}

function doku_create_transaction($trx, $user)
{
    global $config;

    $isProduction = ($config['doku_mode'] ?? 'sandbox') === 'production';
    $baseUrl = $isProduction ? 'https://api.doku.com' : 'https://api-sandbox.doku.com';
    $targetPath = '/checkout/v1/payment';

    $clientId = trim($config['doku_client_id']);
    $secretKey = trim($config['doku_secret_key']);
    $requestId = 'REQ-' . $trx['id'] . '-' . time();
    $timestamp = gmdate('Y-m-d\TH:i:s\Z');
    $invoiceNumber = 'INV-' . $trx['id'];

    $customerEmail = filter_var($user['email'], FILTER_VALIDATE_EMAIL) ? $user['email'] : 'customer' . $user['id'] . '@local.net';
    $customerPhone = !empty($user['phonenumber']) ? preg_replace('/[^0-9]/', '', $user['phonenumber']) : '081234567890';

    $body = [
        'order' => [
            'invoice_number' => $invoiceNumber,
            'amount' => (int) $trx['price'],
            'callback_url' => U . 'voucher/view/' . $trx['id'],
            'auto_redirect' => true
        ],
        'payment' => [
            'payment_due_date' => (int) ($config['doku_expired_time'] ?? 60)
        ],
        'customer' => [
            'id' => 'CUST-' . $user['id'],
            'name' => !empty($user['fullname']) ? $user['fullname'] : $user['username'],
            'email' => $customerEmail,
            'phone' => $customerPhone
        ]
    ];

    $jsonBody = json_encode($body, JSON_UNESCAPED_SLASHES);
    $digest = base64_encode(hash('sha256', $jsonBody, true));

    // DOKU Signature Calculation (HMAC-SHA256)
    $rawSignature = "Client-Id:" . $clientId . "\n"
                  . "Request-Id:" . $requestId . "\n"
                  . "Request-Timestamp:" . $timestamp . "\n"
                  . "Request-Target:" . $targetPath . "\n"
                  . "Digest:" . $digest;

    $signature = "HMACSHA256=" . base64_encode(hash_hmac('sha256', $rawSignature, $secretKey, true));

    $ch = curl_init($baseUrl . $targetPath);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $jsonBody,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Client-Id: ' . $clientId,
            'Request-Id: ' . $requestId,
            'Request-Timestamp: ' . $timestamp,
            'Signature: ' . $signature
        ],
        CURLOPT_TIMEOUT => 30
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $resData = json_decode($response, true);

    if ($httpCode >= 200 && $httpCode < 300 && isset($resData['response']['payment']['url'])) {
        $paymentUrl = $resData['response']['payment']['url'];

        $d = ORM::for_table('tbl_payment_gateway')->where('id', $trx['id'])->find_one();
        $d->gateway_trx_id = $invoiceNumber;
        $d->pg_url_payment = $paymentUrl;
        $d->status = 1; // Unpaid
        $d->save();

        header('Location: ' . $paymentUrl);
        exit();
    } else {
        _log('DOKU Error Response: ' . $response, 'PaymentGateway');
        $errMsg = $resData['error']['message'] ?? 'Gagal membuat sesi pembayaran DOKU';
        r2(U . 'order/view/' . $trx['id'], 'e', $errMsg);
    }
}

function doku_payment_notification()
{
    global $config;

    $rawPayload = file_get_contents('php://input');
    _log('DOKU Webhook Notification: ' . $rawPayload, 'PaymentGateway');

    $data = json_decode($rawPayload, true);
    if (!$data || !isset($data['order']['invoice_number'])) {
        http_response_code(400);
        echo json_encode(['status' => 'INVALID_PAYLOAD']);
        exit();
    }

    $invoiceNumber = $data['order']['invoice_number'];
    $trxId = str_replace('INV-', '', $invoiceNumber);
    $trx = ORM::for_table('tbl_payment_gateway')->where('id', $trxId)->find_one();

    if (!$trx) {
        http_response_code(404);
        echo json_encode(['status' => 'TRANSACTION_NOT_FOUND']);
        exit();
    }

    if ($trx->status == 2) {
        http_response_code(200);
        echo json_encode(['status' => 'ALREADY_PAID']);
        exit();
    }

    $transactionStatus = $data['transaction']['status'] ?? '';

    if (strtoupper($transactionStatus) === 'SUCCESS') {
        // Eksekusi aktivasi user / voucher di MikroTik RouterOS v7
        $user = ORM::for_table('tbl_customers')->where('id', $trx->customer_id)->find_one();
        $plan = ORM::for_table('tbl_plans')->where('id', $trx->plan_id)->find_one();
        $router = ORM::for_table('tbl_routers')->where('name', $trx->routers)->find_one();

        if (Package::rechargeUser($user->id, $router->name, $plan->id, 'DOKU', 'DOKU Payment Gateway')) {
            $trx->status = 2; // Paid
            $trx->paid_date = date('Y-m-d H:i:s');
            $trx->save();

            _log('DOKU: Invoice ' . $invoiceNumber . ' SUCCESS - MikroTik RouterOS v7 User Activated', 'PaymentGateway');
            http_response_code(200);
            echo json_encode(['status' => 'SUCCESS']);
            exit();
        } else {
            _log('DOKU: MikroTik API Activation Error on Invoice ' . $invoiceNumber, 'PaymentGateway');
            http_response_code(500);
            echo json_encode(['status' => 'ROUTER_ACTIVATION_FAILED']);
            exit();
        }
    } else {
        $trx->status = 3; // Failed / Expired
        $trx->save();
        http_response_code(200);
        echo json_encode(['status' => 'NOT_SUCCESS']);
        exit();
    }
}
