#!/usr/bin/env bash

exit_on_battery(){
    local _chassis _battery _state

    _chassis="$(LC_ALL=C hostnamectl | awk '/Chassis/{print $2}')"
    if [[ "${_chassis:?}" != laptop ]]; then
        return 0
    fi

    if _battery="$(LC_ALL=C upower --enumerate | grep battery)"; then
        _state="$(LC_ALL=C upower --show-info "$_battery")"
        if [[ "$_state" =~ state: ]]; then
            if [[ "$_state" =~ state:[^\n]*discharging ]]; then
                exit 0
            fi
        else
            print 'Could not find battery state.'
            exit 1
        fi
    else
        __print=notify print 'The battery is probably disconnected!'
        return 1
    fi
}
exit_on_battery
