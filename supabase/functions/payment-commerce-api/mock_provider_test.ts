import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { MockPaymentProvider, resetMockPaymentStore } from "./mock_provider.ts";
import { resolvePaymentProvider } from "./payment_provider.ts";
import { PaymentError } from "./payment_domain.ts";
import { ZimswitchPaymentProvider } from "./zimswitch_provider.ts";

Deno.test("mock provider is disabled in production", () => {
  assertThrows(
    () =>
      resolvePaymentProvider("mock", {
        DESTINY_ENV: "production",
        PAYMENT_ALLOW_MOCK: "true",
      }),
    PaymentError,
  );
});

Deno.test("mock provider end-to-end simulate without real money", async () => {
  resetMockPaymentStore();
  const mock = new MockPaymentProvider();
  const created = await mock.createPayment({
    intentId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    bookingId: "book",
    currency: "USD",
    amountCents: 5500,
  });
  assertEquals(created.isMock, true);
  assertEquals(created.checkoutUrl?.startsWith("destiny-mock://"), true);
  const simulated = mock.simulateResult(
    created.providerReference,
    "succeeded",
    "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  );
  assertEquals(simulated.status, "succeeded");
  const verified = await mock.verifyPayment(created.providerReference);
  assertEquals(verified.status, "succeeded");
  assertEquals(verified.amountCents, 5500);
});

Deno.test("placeholder providers do not invent APIs", async () => {
  const z = new ZimswitchPaymentProvider();
  await assertRejects(() =>
    z.createPayment({
      intentId: "i",
      bookingId: "b",
      currency: "USD",
      amountCents: 100,
    })
  );
});
