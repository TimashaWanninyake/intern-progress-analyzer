"""
AI Manager - Central Hub for AI Provider Management
=================================================

This file manages all AI providers (OLLAMA, GPT-4, Claude) and provides:
- Provider selection and switching
- Fallback mechanisms if primary provider fails
- Load balancing between providers
- Configuration management
- Provider health monitoring
- Cost optimization

Usage:
    ai_manager = AIManager()
    report = ai_manager.generate_report('ollama', intern_data, 'weekly')
"""

import os
import json
import time
import logging
from typing import Dict, Any, List, Optional
from .base_provider import BaseAIProvider
from .ollama_provider import OllamaProvider
from .openai_provider import OpenAIProvider
from .claude_provider import ClaudeProvider

logger = logging.getLogger(__name__)

class AIManager:
    """
    Central manager for all AI providers.
    Handles provider selection, fallback, and configuration.
    """
    
    def __init__(self):
        self.providers = {}
        self.default_provider = 'ollama'
        self.fallback_order = ['ollama', 'gpt4', 'claude']
        self._initialize_providers()
        
    def _initialize_providers(self):
        """Initialize all available AI providers"""
        try:
            # Initialize OLLAMA (local, free)
            self.providers['ollama'] = OllamaProvider()
            logger.info("OLLAMA provider initialized")
        except Exception as e:
            logger.warning(f"Failed to initialize OLLAMA: {e}")
            
        try:
            # Initialize OpenAI GPT-4 (requires API key)
            self.providers['gpt4'] = OpenAIProvider()
            logger.info("OpenAI GPT-4 provider initialized")
        except Exception as e:
            logger.warning(f"Failed to initialize OpenAI: {e}")
            
        try:
            # Initialize Claude (requires API key)
            self.providers['claude'] = ClaudeProvider()
            logger.info("Claude provider initialized")
        except Exception as e:
            logger.warning(f"Failed to initialize Claude: {e}")
    
    def get_available_providers(self) -> List[Dict[str, Any]]:
        """
        Get list of all providers with their availability status
        
        Returns:
            List of provider information dictionaries
        """
        provider_info = []
        
        for name, provider in self.providers.items():
            try:
                is_available = provider.test_connection()
                models = provider.get_available_models() if is_available else []
                
                # Provider metadata
                metadata = self._get_provider_metadata(name)
                
                provider_info.append({
                    'name': name,
                    'display_name': metadata['display_name'],
                    'description': metadata['description'],
                    'available': is_available,
                    'models': models,
                    'cost': metadata['cost'],
                    'speed': metadata['speed'],
                    'last_error': provider.last_error if not is_available else None
                })
                
            except Exception as e:
                provider_info.append({
                    'name': name,
                    'display_name': self._get_provider_metadata(name)['display_name'],
                    'available': False,
                    'error': str(e)
                })
                
        return provider_info
    
    def _get_provider_metadata(self, provider_name: str) -> Dict[str, str]:
        """Get metadata for a specific provider"""
        metadata = {
            'ollama': {
                'display_name': 'OLLAMA (Local)',
                'description': 'Free local AI processing - fast and private',
                'cost': 'Free',
                'speed': 'Fast'
            },
            'gpt4': {
                'display_name': 'GPT-4 (OpenAI)',
                'description': 'Advanced AI analysis with superior reasoning',
                'cost': 'Paid (~$0.03/1K tokens)',
                'speed': 'Medium'
            },
            'claude': {
                'display_name': 'Claude (Anthropic)',
                'description': 'Detailed insights with professional formatting',
                'cost': 'Paid (~$0.008/1K tokens)',
                'speed': 'Medium'
            }
        }
        return metadata.get(provider_name, {
            'display_name': provider_name.title(),
            'description': 'AI Provider',
            'cost': 'Unknown',
            'speed': 'Unknown'
        })
    
    def generate_report(self, provider_name: str, intern_data: Dict[str, Any], 
                       report_type: str = 'weekly', use_fallback: bool = True) -> Dict[str, Any]:
        """
        Generate AI report using specified provider
        
        Args:
            provider_name: Name of AI provider ('ollama', 'gpt4', 'claude')
            intern_data: Intern logbook data and performance metrics
            report_type: Type of report ('weekly', 'monthly', 'project_summary')
            use_fallback: Whether to try fallback providers if primary fails
            
        Returns:
            Generated report dictionary or error response
        """
        # Try primary provider
        if provider_name in self.providers:
            try:
                logger.info(f"Generating {report_type} report using {provider_name}")
                provider = self.providers[provider_name]
                
                # Test connection first
                if not provider.test_connection():
                    raise Exception(f"{provider_name} is not available")
                
                # Generate report
                report = provider.generate_report(intern_data, report_type)
                
                # Add metadata
                report['provider_used'] = provider_name
                report['fallback_used'] = False
                
                logger.info(f"Report generated successfully using {provider_name}")
                return report
                
            except Exception as e:
                logger.error(f"Error with {provider_name}: {e}")
                
                if use_fallback:
                    return self._try_fallback_providers(provider_name, intern_data, report_type, str(e))
                else:
                    return {
                        'success': False,
                        'error': f"Failed to generate report with {provider_name}: {e}",
                        'provider_used': provider_name
                    }
        else:
            error_msg = f"Provider '{provider_name}' not found"
            logger.error(error_msg)
            
            if use_fallback:
                return self._try_fallback_providers(provider_name, intern_data, report_type, error_msg)
            else:
                return {
                    'success': False,
                    'error': error_msg,
                    'available_providers': list(self.providers.keys())
                }
    
    def _try_fallback_providers(self, failed_provider: str, intern_data: Dict[str, Any], 
                               report_type: str, original_error: str) -> Dict[str, Any]:
        """
        Try fallback providers when primary provider fails
        
        Args:
            failed_provider: Name of provider that failed
            intern_data: Intern data for report generation
            report_type: Type of report to generate
            original_error: Error message from failed provider
            
        Returns:
            Report from fallback provider or final error
        """
        logger.info(f"Trying fallback providers after {failed_provider} failed")
        
        # Try providers in fallback order, excluding the failed one
        fallback_providers = [p for p in self.fallback_order if p != failed_provider and p in self.providers]
        
        for fallback_provider in fallback_providers:
            try:
                logger.info(f"Attempting fallback to {fallback_provider}")
                provider = self.providers[fallback_provider]
                
                if provider.test_connection():
                    report = provider.generate_report(intern_data, report_type)
                    report['provider_used'] = fallback_provider
                    report['fallback_used'] = True
                    report['original_provider'] = failed_provider
                    report['original_error'] = original_error
                    
                    logger.info(f"Successfully generated report using fallback provider {fallback_provider}")
                    return report
                    
            except Exception as e:
                logger.warning(f"Fallback provider {fallback_provider} also failed: {e}")
                continue
        
        # All providers failed
        return {
            'success': False,
            'error': f"All AI providers failed. Original error: {original_error}",
            'provider_used': failed_provider,
            'fallback_attempted': True,
            'available_providers': list(self.providers.keys())
        }
    
    def set_default_provider(self, provider_name: str) -> bool:
        """
        Set default AI provider
        
        Args:
            provider_name: Name of provider to set as default
            
        Returns:
            True if successful, False if provider not available
        """
        if provider_name in self.providers:
            if self.providers[provider_name].test_connection():
                self.default_provider = provider_name
                logger.info(f"Default provider set to {provider_name}")
                return True
            else:
                logger.warning(f"Cannot set {provider_name} as default - not available")
                return False
        else:
            logger.error(f"Provider {provider_name} not found")
            return False
    
    def get_provider_health(self) -> Dict[str, Any]:
        """
        Get health status of all providers
        
        Returns:
            Dictionary with provider health information
        """
        health_status = {
            'timestamp': str(int(time.time())),
            'providers': {}
        }
        
        for name, provider in self.providers.items():
            try:
                start_time = time.time()
                is_healthy = provider.test_connection()
                response_time = round((time.time() - start_time) * 1000, 2)  # ms
                
                health_status['providers'][name] = {
                    'healthy': is_healthy,
                    'response_time_ms': response_time,
                    'last_error': provider.last_error if not is_healthy else None,
                    'models': provider.get_available_models() if is_healthy else []
                }
                
            except Exception as e:
                health_status['providers'][name] = {
                    'healthy': False,
                    'error': str(e),
                    'response_time_ms': None
                }
        
        return health_status
    
    def estimate_report_cost(self, provider_name: str, intern_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Estimate cost for generating a report with specific provider
        
        Args:
            provider_name: Name of AI provider
            intern_data: Intern data to analyze
            
        Returns:
            Cost estimation information
        """
        if provider_name not in self.providers:
            return {'error': f'Provider {provider_name} not found'}
        
        try:
            provider = self.providers[provider_name]
            
            # Format data to estimate token count
            formatted_data = provider.format_intern_data_for_ai(intern_data)
            estimated_input_tokens = len(formatted_data.split()) * 1.3  # Rough estimation
            estimated_output_tokens = 500  # Average output length
            total_tokens = estimated_input_tokens + estimated_output_tokens
            
            # Cost per provider (rough estimates)
            cost_per_1k_tokens = {
                'ollama': 0.0,  # Free
                'gpt4': 0.03,   # GPT-4 pricing
                'claude': 0.008  # Claude pricing
            }
            
            cost = (total_tokens / 1000) * cost_per_1k_tokens.get(provider_name, 0.0)
            
            return {
                'provider': provider_name,
                'estimated_input_tokens': int(estimated_input_tokens), 
                'estimated_output_tokens': int(estimated_output_tokens),
                'total_tokens': int(total_tokens),
                'estimated_cost_usd': round(cost, 4),
                'is_free': cost == 0.0
            }
            
        except Exception as e:
            return {'error': f'Cost estimation failed: {e}'}
    
    def get_recommended_provider(self, intern_data: Dict[str, Any], priority: str = 'balanced') -> str:
        """
        Get recommended provider based on data size and priority
        
        Args:
            intern_data: Intern data to analyze
            priority: 'cost' (prefer free), 'quality' (prefer best), 'speed' (prefer fast)
            
        Returns:
            Recommended provider name
        """
        available_providers = [name for name, provider in self.providers.items() if provider.test_connection()]
        
        if not available_providers:
            return self.default_provider
        
        if priority == 'cost':
            # Prefer free providers
            if 'ollama' in available_providers:
                return 'ollama'
        elif priority == 'quality':
            # Prefer advanced providers
            for provider in ['gpt4', 'claude', 'ollama']:
                if provider in available_providers:
                    return provider
        elif priority == 'speed':
            # Prefer fast providers
            for provider in ['ollama', 'gpt4', 'claude']:
                if provider in available_providers:
                    return provider
        
        # Default balanced approach
        return available_providers[0] if available_providers else self.default_provider