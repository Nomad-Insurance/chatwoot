<script>
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConfig } from 'dashboard/composables/useConfig';
import { useAccount } from 'dashboard/composables/useAccount';
import accountBrandingAPI from 'dashboard/api/accountBranding';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'next/input/Input.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import AccountId from './components/AccountId.vue';
import BuildInfo from './components/BuildInfo.vue';
import AccountDelete from './components/AccountDelete.vue';
import AudioTranscription from './components/AudioTranscription.vue';
import SectionLayout from './components/SectionLayout.vue';

export default {
  components: {
    BaseSettingsHeader,
    NextButton,
    AccountId,
    BuildInfo,
    AccountDelete,
    AudioTranscription,
    SectionLayout,
    WithLabel,
    NextInput,
  },
  setup() {
    const { updateUISettings, uiSettings } = useUISettings();
    const { enabledLanguages } = useConfig();
    const { accountId } = useAccount();
    const v$ = useVuelidate();

    return { updateUISettings, uiSettings, v$, enabledLanguages, accountId };
  },
  data() {
    return {
      id: '',
      name: '',
      locale: 'en',
      domain: '',
      supportEmail: '',
      features: {},
      brandingName: '',
      brandingInstallationName: '',
      brandingBrandUrl: '',
      brandingWidgetBrandUrl: '',
      brandingTermsUrl: '',
      brandingPrivacyUrl: '',
      brandingPrimaryColor: '',
      logoUrl: '',
      logoDarkUrl: '',
      logoThumbnailUrl: '',
      logoFile: null,
      logoDarkFile: null,
      logoThumbnailFile: null,
      removeLogo: false,
      removeLogoDark: false,
      removeLogoThumbnail: false,
      isBrandingLoading: false,
      isBrandingUpdating: false,
    };
  },
  validations: {
    name: {
      required,
    },
    locale: {
      required,
    },
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      uiFlags: 'accounts/getUIFlags',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      isOnChatwootCloud: 'globalConfig/isOnChatwootCloud',
    }),
    showAudioTranscriptionConfig() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CAPTAIN
      );
    },
    languagesSortedByCode() {
      const enabledLanguages = [...this.enabledLanguages];
      return enabledLanguages.sort((l1, l2) =>
        l1.iso_639_1_code.localeCompare(l2.iso_639_1_code)
      );
    },
    isUpdating() {
      return this.uiFlags.isUpdating;
    },
    featureInboundEmailEnabled() {
      return !!this.features?.inbound_emails;
    },
    featureCustomReplyDomainEnabled() {
      return (
        this.featureInboundEmailEnabled && !!this.features.custom_reply_domain
      );
    },
    featureCustomReplyEmailEnabled() {
      return (
        this.featureInboundEmailEnabled && !!this.features.custom_reply_email
      );
    },
    currentAccount() {
      return this.getAccount(this.accountId) || {};
    },
  },
  watch: {
    'currentAccount.id'(id) {
      if (id) {
        this.initializeAccount();
      }
    },
  },
  mounted() {
    // Account already in the store (navigated in): seed immediately.
    if (this.currentAccount.id) {
      this.initializeAccount();
    }
  },
  methods: {
    async initializeAccount() {
      try {
        const { name, locale, id, domain, support_email, features } =
          this.getAccount(this.accountId);

        const effectiveLocale = this.uiSettings?.locale || locale;
        if (effectiveLocale) {
          this.$root.$i18n.locale = effectiveLocale;
        }
        this.name = name;
        this.locale = locale;
        this.id = id;
        this.domain = domain;
        this.supportEmail = support_email;
        this.features = features;
        await this.fetchBranding();
      } catch (error) {
        // Ignore error
      }
    },
    async fetchBranding() {
      this.isBrandingLoading = true;
      try {
        const { data } = await accountBrandingAPI.get(this.accountId);
        this.brandingName = data.name || '';
        this.brandingInstallationName = data.installation_name || '';
        this.brandingBrandUrl = data.brand_url || '';
        this.brandingWidgetBrandUrl = data.widget_brand_url || '';
        this.brandingTermsUrl = data.terms_url || '';
        this.brandingPrivacyUrl = data.privacy_url || '';
        this.brandingPrimaryColor = data.primary_color || '';
        this.logoUrl = data.logo_url || '';
        this.logoDarkUrl = data.logo_dark_url || '';
        this.logoThumbnailUrl = data.logo_thumbnail_url || '';
      } catch (error) {
        // Ignore error
      } finally {
        this.isBrandingLoading = false;
      }
    },

    async updateAccount() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        useAlert(this.$t('GENERAL_SETTINGS.FORM.ERROR'));
        return;
      }
      try {
        await this.$store.dispatch('accounts/update', {
          locale: this.locale,
          name: this.name,
          domain: this.domain,
          support_email: this.supportEmail,
        });
        // If user locale is set, update the locale with user locale
        const updatedLocale = this.uiSettings?.locale || this.locale;
        if (updatedLocale) {
          this.$root.$i18n.locale = updatedLocale;
        }
        this.getAccount(this.id).locale = this.locale;
        useAlert(this.$t('GENERAL_SETTINGS.UPDATE.SUCCESS'));
      } catch (error) {
        useAlert(this.$t('GENERAL_SETTINGS.UPDATE.ERROR'));
      }
    },
    async updateBranding() {
      this.isBrandingUpdating = true;
      const hasFilesOrRemovals =
        this.logoFile ||
        this.logoDarkFile ||
        this.logoThumbnailFile ||
        this.removeLogo ||
        this.removeLogoDark ||
        this.removeLogoThumbnail;

      try {
        let response;
        if (hasFilesOrRemovals) {
          const formData = new FormData();
          formData.append('branding[name]', this.brandingName);
          formData.append(
            'branding[installation_name]',
            this.brandingInstallationName
          );
          formData.append('branding[brand_url]', this.brandingBrandUrl);
          formData.append(
            'branding[widget_brand_url]',
            this.brandingWidgetBrandUrl
          );
          formData.append('branding[terms_url]', this.brandingTermsUrl);
          formData.append('branding[privacy_url]', this.brandingPrivacyUrl);
          formData.append('branding[primary_color]', this.brandingPrimaryColor);
          if (this.logoFile) {
            formData.append('branding[logo]', this.logoFile);
          }
          if (this.logoDarkFile) {
            formData.append('branding[logo_dark]', this.logoDarkFile);
          }
          if (this.logoThumbnailFile) {
            formData.append('branding[logo_thumbnail]', this.logoThumbnailFile);
          }
          if (this.removeLogo) {
            formData.append('branding[remove_logo]', true);
          }
          if (this.removeLogoDark) {
            formData.append('branding[remove_logo_dark]', true);
          }
          if (this.removeLogoThumbnail) {
            formData.append('branding[remove_logo_thumbnail]', true);
          }
          response = await accountBrandingAPI.update(
            this.accountId,
            formData,
            true
          );
        } else {
          response = await accountBrandingAPI.update(this.accountId, {
            name: this.brandingName || null,
            installation_name: this.brandingInstallationName || null,
            brand_url: this.brandingBrandUrl || null,
            widget_brand_url: this.brandingWidgetBrandUrl || null,
            terms_url: this.brandingTermsUrl || null,
            privacy_url: this.brandingPrivacyUrl || null,
            primary_color: this.brandingPrimaryColor || null,
          });
        }

        const data = response.data;
        this.brandingName = data.name || '';
        this.brandingInstallationName = data.installation_name || '';
        this.brandingBrandUrl = data.brand_url || '';
        this.brandingWidgetBrandUrl = data.widget_brand_url || '';
        this.brandingTermsUrl = data.terms_url || '';
        this.brandingPrivacyUrl = data.privacy_url || '';
        this.brandingPrimaryColor = data.primary_color || '';
        this.logoUrl = data.logo_url || '';
        this.logoDarkUrl = data.logo_dark_url || '';
        this.logoThumbnailUrl = data.logo_thumbnail_url || '';
        this.logoFile = null;
        this.logoDarkFile = null;
        this.logoThumbnailFile = null;
        this.removeLogo = false;
        this.removeLogoDark = false;
        this.removeLogoThumbnail = false;
        useAlert(this.$t('GENERAL_SETTINGS.BRANDING_SECTION.UPDATE.SUCCESS'));
      } catch (error) {
        useAlert(this.$t('GENERAL_SETTINGS.BRANDING_SECTION.UPDATE.ERROR'));
      } finally {
        this.isBrandingUpdating = false;
      }
    },
    handleFileChange(event, type) {
      const file = event.target.files[0];
      if (type === 'logo') {
        this.logoFile = file;
      } else if (type === 'logo_dark') {
        this.logoDarkFile = file;
      } else if (type === 'logo_thumbnail') {
        this.logoThumbnailFile = file;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full max-w-2xl ltr:mr-auto rtl:ml-auto">
    <BaseSettingsHeader :title="$t('GENERAL_SETTINGS.TITLE')" />
    <div class="flex-grow flex-shrink min-w-0 mt-3">
      <SectionLayout
        :title="$t('GENERAL_SETTINGS.FORM.GENERAL_SECTION.TITLE')"
        :description="$t('GENERAL_SETTINGS.FORM.GENERAL_SECTION.NOTE')"
        class="!pt-0"
      >
        <form
          v-if="!uiFlags.isFetchingItem"
          class="grid gap-4"
          @submit.prevent="updateAccount"
        >
          <WithLabel
            name="account-name"
            :has-error="v$.name.$error"
            :label="$t('GENERAL_SETTINGS.FORM.NAME.LABEL')"
            :error-message="$t('GENERAL_SETTINGS.FORM.NAME.ERROR')"
          >
            <NextInput
              v-model="name"
              type="text"
              class="w-full"
              :placeholder="$t('GENERAL_SETTINGS.FORM.NAME.PLACEHOLDER')"
              @blur="v$.name.$touch"
            />
          </WithLabel>
          <WithLabel
            name="site-language"
            :has-error="v$.locale.$error"
            :label="$t('GENERAL_SETTINGS.FORM.LANGUAGE.LABEL')"
            :error-message="$t('GENERAL_SETTINGS.FORM.LANGUAGE.ERROR')"
          >
            <select v-model="locale" class="!mb-0 text-sm">
              <option
                v-for="lang in languagesSortedByCode"
                :key="lang.iso_639_1_code"
                :value="lang.iso_639_1_code"
              >
                {{ lang.name }}
              </option>
            </select>
          </WithLabel>
          <WithLabel
            v-if="featureCustomReplyDomainEnabled"
            name="custom-domain"
            :label="$t('GENERAL_SETTINGS.FORM.DOMAIN.LABEL')"
          >
            <NextInput
              v-model="domain"
              type="text"
              class="w-full"
              :placeholder="$t('GENERAL_SETTINGS.FORM.DOMAIN.PLACEHOLDER')"
            />
            <template #help>
              {{
                featureInboundEmailEnabled &&
                $t('GENERAL_SETTINGS.FORM.FEATURES.INBOUND_EMAIL_ENABLED')
              }}

              {{
                featureCustomReplyDomainEnabled &&
                $t('GENERAL_SETTINGS.FORM.FEATURES.CUSTOM_EMAIL_DOMAIN_ENABLED')
              }}
            </template>
          </WithLabel>
          <WithLabel
            v-if="featureCustomReplyEmailEnabled"
            name="support-email"
            :label="$t('GENERAL_SETTINGS.FORM.SUPPORT_EMAIL.LABEL')"
          >
            <NextInput
              v-model="supportEmail"
              type="text"
              class="w-full"
              :placeholder="
                $t('GENERAL_SETTINGS.FORM.SUPPORT_EMAIL.PLACEHOLDER')
              "
            />
          </WithLabel>
          <div>
            <NextButton blue :is-loading="isUpdating" type="submit">
              {{ $t('GENERAL_SETTINGS.SUBMIT') }}
            </NextButton>
          </div>
        </form>
      </SectionLayout>

      <SectionLayout
        :title="$t('GENERAL_SETTINGS.BRANDING_SECTION.TITLE')"
        :description="$t('GENERAL_SETTINGS.BRANDING_SECTION.NOTE')"
        class="mt-6"
      >
        <form
          v-if="!isBrandingLoading"
          class="grid gap-4"
          @submit.prevent="updateBranding"
        >
          <WithLabel
            :label="$t('GENERAL_SETTINGS.BRANDING_SECTION.NAME.LABEL')"
          >
            <NextInput
              v-model="brandingName"
              type="text"
              class="w-full"
              :placeholder="
                $t('GENERAL_SETTINGS.BRANDING_SECTION.NAME.PLACEHOLDER')
              "
            />
          </WithLabel>
          <WithLabel
            :label="
              $t('GENERAL_SETTINGS.BRANDING_SECTION.INSTALLATION_NAME.LABEL')
            "
          >
            <NextInput
              v-model="brandingInstallationName"
              type="text"
              class="w-full"
              :placeholder="
                $t(
                  'GENERAL_SETTINGS.BRANDING_SECTION.INSTALLATION_NAME.PLACEHOLDER'
                )
              "
            />
          </WithLabel>
          <WithLabel
            :label="$t('GENERAL_SETTINGS.BRANDING_SECTION.BRAND_URL.LABEL')"
          >
            <NextInput
              v-model="brandingBrandUrl"
              type="text"
              class="w-full"
              :placeholder="
                $t('GENERAL_SETTINGS.BRANDING_SECTION.BRAND_URL.PLACEHOLDER')
              "
            />
          </WithLabel>
          <WithLabel
            :label="
              $t('GENERAL_SETTINGS.BRANDING_SECTION.WIDGET_BRAND_URL.LABEL')
            "
          >
            <NextInput
              v-model="brandingWidgetBrandUrl"
              type="text"
              class="w-full"
              :placeholder="
                $t(
                  'GENERAL_SETTINGS.BRANDING_SECTION.WIDGET_BRAND_URL.PLACEHOLDER'
                )
              "
            />
          </WithLabel>
          <WithLabel
            :label="$t('GENERAL_SETTINGS.BRANDING_SECTION.TERMS_URL.LABEL')"
          >
            <NextInput
              v-model="brandingTermsUrl"
              type="text"
              class="w-full"
              :placeholder="
                $t('GENERAL_SETTINGS.BRANDING_SECTION.TERMS_URL.PLACEHOLDER')
              "
            />
          </WithLabel>
          <WithLabel
            :label="$t('GENERAL_SETTINGS.BRANDING_SECTION.PRIVACY_URL.LABEL')"
          >
            <NextInput
              v-model="brandingPrivacyUrl"
              type="text"
              class="w-full"
              :placeholder="
                $t('GENERAL_SETTINGS.BRANDING_SECTION.PRIVACY_URL.PLACEHOLDER')
              "
            />
          </WithLabel>
          <WithLabel
            :label="$t('GENERAL_SETTINGS.BRANDING_SECTION.PRIMARY_COLOR.LABEL')"
          >
            <NextInput
              v-model="brandingPrimaryColor"
              type="text"
              class="w-full"
              :placeholder="
                $t(
                  'GENERAL_SETTINGS.BRANDING_SECTION.PRIMARY_COLOR.PLACEHOLDER'
                )
              "
            />
            <template #help>
              {{
                $t('GENERAL_SETTINGS.BRANDING_SECTION.PRIMARY_COLOR.HELP_TEXT')
              }}
            </template>
          </WithLabel>

          <div class="grid gap-6">
            <div>
              <p class="text-sm font-medium mb-2">
                {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO.LABEL') }}
              </p>
              <div class="flex items-center gap-4 mb-2">
                <img
                  v-if="logoUrl"
                  :src="logoUrl"
                  :alt="$t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO.LABEL')"
                  class="h-12"
                />
                <span v-else class="text-xs text-slate-500">
                  {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO.EMPTY') }}
                </span>
              </div>
              <input
                type="file"
                accept="image/*"
                @change="event => handleFileChange(event, 'logo')"
              />
              <label
                class="flex items-center gap-2 mt-2 text-xs text-slate-600"
              >
                <input v-model="removeLogo" type="checkbox" />
                {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO.REMOVE') }}
              </label>
            </div>

            <div>
              <p class="text-sm font-medium mb-2">
                {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_DARK.LABEL') }}
              </p>
              <div class="flex items-center gap-4 mb-2">
                <img
                  v-if="logoDarkUrl"
                  :src="logoDarkUrl"
                  :alt="$t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_DARK.LABEL')"
                  class="h-12"
                />
                <span v-else class="text-xs text-slate-500">
                  {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_DARK.EMPTY') }}
                </span>
              </div>
              <input
                type="file"
                accept="image/*"
                @change="event => handleFileChange(event, 'logo_dark')"
              />
              <label
                class="flex items-center gap-2 mt-2 text-xs text-slate-600"
              >
                <input v-model="removeLogoDark" type="checkbox" />
                {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_DARK.REMOVE') }}
              </label>
            </div>

            <div>
              <p class="text-sm font-medium mb-2">
                {{
                  $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_THUMBNAIL.LABEL')
                }}
              </p>
              <div class="flex items-center gap-4 mb-2">
                <img
                  v-if="logoThumbnailUrl"
                  :src="logoThumbnailUrl"
                  :alt="
                    $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_THUMBNAIL.LABEL')
                  "
                  class="h-12"
                />
                <span v-else class="text-xs text-slate-500">
                  {{
                    $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_THUMBNAIL.EMPTY')
                  }}
                </span>
              </div>
              <input
                type="file"
                accept="image/*"
                @change="event => handleFileChange(event, 'logo_thumbnail')"
              />
              <label
                class="flex items-center gap-2 mt-2 text-xs text-slate-600"
              >
                <input v-model="removeLogoThumbnail" type="checkbox" />
                {{
                  $t('GENERAL_SETTINGS.BRANDING_SECTION.LOGO_THUMBNAIL.REMOVE')
                }}
              </label>
            </div>
          </div>

          <div>
            <NextButton blue :is-loading="isBrandingUpdating" type="submit">
              {{ $t('GENERAL_SETTINGS.BRANDING_SECTION.SUBMIT') }}
            </NextButton>
          </div>
        </form>
        <woot-loading-state v-else />
      </SectionLayout>

      <woot-loading-state v-if="uiFlags.isFetchingItem" />
    </div>
    <AudioTranscription v-if="showAudioTranscriptionConfig" />
    <AccountId />
    <div v-if="!uiFlags.isFetchingItem && isOnChatwootCloud">
      <AccountDelete />
    </div>
    <BuildInfo />
  </div>
</template>
