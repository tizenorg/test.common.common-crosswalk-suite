Name:            common-crosswalk-suite
Summary:         Crosswalk suite for Tizen Common
Version:         1.1
Release:         0
License:         GPL-2.0
Group:           Development/Testing
Source:          %{name}-%{version}.tar.gz
Source1001:      %{name}.manifest
BuildArch:       noarch
Requires:        common-suite-launcher
Requires:        testkit-lite
Requires:        testkit-stub


%description
The common-crosswalk-suite validates web features of the Tizen Common image : web W3C api and device api using crosswalk


%prep
%setup -q
cp %{SOURCE1001} .


%build


%install
install -d %{buildroot}/%{_datadir}/tests/common/%{name}
install -m 0755 runtest %{buildroot}/%{_datadir}/tests/common/%{name}
install -m 0644 *.xml %{buildroot}/%{_datadir}/tests/common/%{name}
cp -r TESTDIR %{buildroot}/%{_datadir}/tests/common/%{name}


%files
%manifest %{name}.manifest
%defattr(-,root,root)
%{_datadir}/tests/common/%{name}
