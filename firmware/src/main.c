#include <stdlib.h>

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/device.h>
#include <zephyr/drivers/counter.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/random/random.h>
#include <zephyr/sys/byteorder.h>

LOG_MODULE_REGISTER(reaction_duel, LOG_LEVEL_DBG);

/* GPIO */
static const struct gpio_dt_spec btn = GPIO_DT_SPEC_GET(DT_ALIAS(sw0), gpios);
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(DT_ALIAS(led0), gpios);
static struct gpio_callback btn_cb;

/* Timer / counter */
static const struct device *counter_dev = DEVICE_DT_GET(DT_NODELABEL(timer0));
static uint32_t start_ticks;
static volatile bool waiting_for_press;

/* Score queue (game_thread -> ble_thread) */
K_MSGQ_DEFINE(score_queue, sizeof(uint32_t), 4, 4);

/* BLE GATT service */
#define REACTION_SVC_UUID_VAL \
    BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef0)
#define REACTION_CHR_UUID_VAL \
    BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef1)

static struct bt_uuid_128 reaction_svc_uuid = BT_UUID_INIT_128(REACTION_SVC_UUID_VAL);
static struct bt_uuid_128 reaction_chr_uuid = BT_UUID_INIT_128(REACTION_CHR_UUID_VAL);

static bool notify_enabled;

static void ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
    ARG_UNUSED(attr);
    notify_enabled = (value == BT_GATT_CCC_NOTIFY);
    LOG_INF("Notifications %s", notify_enabled ? "enabled" : "disabled");
}

BT_GATT_SERVICE_DEFINE(reaction_svc,
    BT_GATT_PRIMARY_SERVICE(&reaction_svc_uuid),
    BT_GATT_CHARACTERISTIC(&reaction_chr_uuid.uuid,
        BT_GATT_CHRC_NOTIFY,
        BT_GATT_PERM_NONE,
        NULL, NULL, NULL),
    BT_GATT_CCC(ccc_changed,
        BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

static void ble_notify_score(uint32_t score_ms)
{
    if (!notify_enabled) {
        LOG_WRN("No subscriber - score dropped");
        return;
    }

    uint8_t buf[4];
    sys_put_le32(score_ms, buf);

    int err = bt_gatt_notify(NULL, &reaction_svc.attrs[2], buf, sizeof(buf));
    if (err) {
        LOG_ERR("bt_gatt_notify failed: %d", err);
    }
}

/* BLE advertising */
static const struct bt_data ad[] = {
    BT_DATA_BYTES(BT_DATA_FLAGS, BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR),
    BT_DATA_BYTES(BT_DATA_UUID128_ALL, REACTION_SVC_UUID_VAL),
};

/* GPIO ISR */
static void btn_pressed(const struct device *dev, struct gpio_callback *cb, uint32_t pins)
{
    ARG_UNUSED(dev);
    ARG_UNUSED(cb);
    ARG_UNUSED(pins);

    if (!waiting_for_press) {
        return;
    }
    waiting_for_press = false;

    uint32_t now;
    counter_get_value(counter_dev, &now);
    uint32_t freq = counter_get_frequency(counter_dev);
    uint32_t elapsed_ms = (uint32_t)(((uint64_t)(now - start_ticks) * 1000U) / freq);

    LOG_INF("Reaction: %u ms", elapsed_ms);
    (void)k_msgq_put(&score_queue, &elapsed_ms, K_NO_WAIT);
}

/* Game thread */
#define GAME_STACK 1024
#define GAME_PRIO 5
K_THREAD_STACK_DEFINE(game_stack, GAME_STACK);
static struct k_thread game_thread_data;

static void game_thread(void *a, void *b, void *c)
{
    ARG_UNUSED(a);
    ARG_UNUSED(b);
    ARG_UNUSED(c);

    while (1) {
        /* Random delay 1.5-4.5 s before LED fires. */
        k_sleep(K_MSEC(1500 + (sys_rand32_get() % 3000U)));

        gpio_pin_set_dt(&led, 1);
        counter_get_value(counter_dev, &start_ticks);
        waiting_for_press = true;
        LOG_DBG("LED on - waiting for press");

        /* 2-second window to react. */
        k_sleep(K_MSEC(2000));

        if (waiting_for_press) {
            waiting_for_press = false;
            LOG_INF("Too slow!");
        }
        gpio_pin_set_dt(&led, 0);
    }
}

/* BLE thread */
#define BLE_STACK 1024
#define BLE_PRIO 7
K_THREAD_STACK_DEFINE(ble_stack, BLE_STACK);
static struct k_thread ble_thread_data;

static void ble_thread(void *a, void *b, void *c)
{
    ARG_UNUSED(a);
    ARG_UNUSED(b);
    ARG_UNUSED(c);

    uint32_t score_ms;
    while (1) {
        k_msgq_get(&score_queue, &score_ms, K_FOREVER);
        ble_notify_score(score_ms);
    }
}

void main(void)
{
    gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
    gpio_pin_configure_dt(&btn, GPIO_INPUT);
    gpio_pin_interrupt_configure_dt(&btn, GPIO_INT_EDGE_TO_ACTIVE);
    gpio_init_callback(&btn_cb, btn_pressed, BIT(btn.pin));
    gpio_add_callback(btn.port, &btn_cb);

    counter_start(counter_dev);

    bt_enable(NULL);
    bt_le_adv_start(BT_LE_ADV_CONN_NAME, ad, ARRAY_SIZE(ad), NULL, 0);
    LOG_INF("Advertising as \"%s\"", CONFIG_BT_DEVICE_NAME);

    k_thread_create(&game_thread_data, game_stack, GAME_STACK,
                    game_thread, NULL, NULL, NULL, GAME_PRIO, 0, K_NO_WAIT);
    k_thread_create(&ble_thread_data, ble_stack, BLE_STACK,
                    ble_thread, NULL, NULL, NULL, BLE_PRIO, 0, K_NO_WAIT);
}
