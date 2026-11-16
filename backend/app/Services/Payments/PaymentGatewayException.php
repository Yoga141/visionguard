<?php

namespace App\Services\Payments;

use RuntimeException;

/** Gerbang pembayaran gagal/tidak tersedia → 503. */
class PaymentGatewayException extends RuntimeException {}
