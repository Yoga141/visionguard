<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\Payments\PaymentManager;
use App\Services\Payments\PaymentNotificationService;
use App\Services\Payments\SimulationGateway;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

/**
 * Halaman web pembayaran (§8.4):
 * - finish / unfinish / error: tujuan redirect Snap; meminta pengguna kembali ke aplikasi.
 *   Status di query string hanya informasi — kredit hanya dari notifikasi bersignature.
 * - simulate: halaman bayar tiruan (mode simulation saja).
 */
class PaymentPageController extends Controller
{
    public function finish(Request $request): View
    {
        return $this->result($request, 'finish');
    }

    public function unfinish(Request $request): View
    {
        return $this->result($request, 'unfinish');
    }

    public function error(Request $request): View
    {
        return $this->result($request, 'error');
    }

    public function simulate(string $orderCode, PaymentManager $payments, SimulationGateway $simulation): View
    {
        $order = $this->simulatableOrder($orderCode, $payments, $simulation);

        return view('payments.simulate', ['order' => $order->load('package')]);
    }

    public function simulatePay(
        Request $request,
        string $orderCode,
        PaymentManager $payments,
        SimulationGateway $simulation,
        PaymentNotificationService $notifications,
    ): RedirectResponse {
        $order = $this->simulatableOrder($orderCode, $payments, $simulation);
        $status = $request->validate([
            'status' => ['required', Rule::in(['settlement', 'expire', 'cancel', 'deny'])],
        ])['status'];

        $notifications->handle($simulation->buildNotification($order, $status), $simulation);

        $page = $status === 'settlement' ? 'payments.finish' : 'payments.unfinish';

        return redirect()->route($page, [
            'order_id' => $order->order_code,
            'transaction_status' => $status,
        ]);
    }

    private function simulatableOrder(string $orderCode, PaymentManager $payments, SimulationGateway $simulation): Order
    {
        abort_unless($payments->isSimulation(), 404);
        abort_if(app()->isProduction(), 404);

        return Order::where('order_code', $orderCode)->firstOrFail();
    }

    private function result(Request $request, string $variant): View
    {
        $order = Order::with('package')->where('order_code', (string) $request->query('order_id'))->first();

        return view('payments.result', [
            'variant' => $variant,
            'order' => $order,
        ]);
    }
}
