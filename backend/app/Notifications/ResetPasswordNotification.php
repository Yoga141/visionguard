<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

/** Email tautan reset kata sandi (UC-03), Bahasa Indonesia. Tautan → halaman web `password.reset`. */
class ResetPasswordNotification extends ResetPassword
{
    public function toMail($notifiable): MailMessage
    {
        $minutes = (int) config('auth.passwords.users.expire');

        return (new MailMessage)
            ->subject('Reset kata sandi VisionGuard')
            ->greeting('Halo, '.$notifiable->name)
            ->line('Kami menerima permintaan untuk mengganti kata sandi akun VisionGuard Anda.')
            ->action('Buat kata sandi baru', $this->resetUrl($notifiable))
            ->line("Tautan ini berlaku {$minutes} menit.")
            ->line('Jika Anda tidak meminta reset, abaikan email ini.')
            ->salutation('Salam, Tim VisionGuard');
    }
}
