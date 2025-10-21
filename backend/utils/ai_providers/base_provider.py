"""
Abstract Base Provider for AI Services
====================================

This file defines the interface that all AI providers must implement.
It ensures consistency across different AI services (OLLAMA, GPT-4, Claude).

Key Features:
- Abstract methods for report generation
- Common error handling patterns
- Token counting utilities
- Response formatting standards
- Connection testing interface

All AI providers (OLLAMA, OpenAI, Claude) inherit from this base class.
"""

from abc import ABC, abstractmethod
import json
import time
from typing import Dict, Any, List, Optional

class BaseAIProvider(ABC):
    """
    Abstract base class for all AI providers.
    Defines the interface that all AI services must implement.
    """
    
    def __init__(self):
        self.provider_name = self.__class__.__name__.lower().replace('provider', '')
        self.is_available = False
        self.last_error = None
        
    @abstractmethod
    def generate_report(self, intern_data: Dict[str, Any], report_type: str = 'weekly') -> Dict[str, Any]:
        """
        Generate AI report from intern data
        
        Args:
            intern_data: Dictionary containing logbook entries and performance metrics
            report_type: Type of report ('weekly', 'monthly', 'project_summary')
            
        Returns:
            Dictionary containing the generated report with structure:
            {
                'summary': str,
                'individual_analysis': List[Dict],
                'challenges': List[str],
                'recommendations': List[str],
                'performance_scores': Dict,
                'generated_at': str,
                'provider': str
            }
        """
        pass
        
    @abstractmethod
    def test_connection(self) -> bool:
        """
        Test if the AI provider is available and working
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        pass
        
    @abstractmethod
    def get_available_models(self) -> List[str]:
        """
        Get list of available AI models for this provider
        
        Returns:
            List of model names available
        """
        pass
        
    def format_intern_data_for_ai(self, intern_data: Dict[str, Any]) -> str:
        """
        Format intern data into a text prompt for AI analysis
        
        Args:
            intern_data: Raw intern data from database
            
        Returns:
            Formatted text string for AI prompt
        """
        prompt_parts = []
        
        # Add project context
        if 'project_info' in intern_data:
            project = intern_data['project_info']
            prompt_parts.append(f"PROJECT: {project.get('name', 'Unknown')}")
            prompt_parts.append(f"DESCRIPTION: {project.get('description', 'No description')}")
            prompt_parts.append("="*50)
        
        # Add intern analysis
        if 'interns_data' in intern_data:
            for intern_id, intern_info in intern_data['interns_data'].items():
                intern = intern_info['intern_info']
                entries = intern_info['logbook_entries']
                
                prompt_parts.append(f"\nINTERN: {intern['name']} ({intern['slt_id']})")
                prompt_parts.append("-" * 30)
                
                # Recent logbook entries
                for entry in entries[-7:]:  # Last 7 entries
                    prompt_parts.append(f"Date: {entry['date']}")
                    prompt_parts.append(f"Status: {entry['status']}")
                    prompt_parts.append(f"Task Stack: {entry['task_stack']}")
                    prompt_parts.append(f"Work Done: {entry['todays_work']}")
                    prompt_parts.append(f"Challenges: {entry['challenges']}")
                    prompt_parts.append(f"Tomorrow Plan: {entry['tomorrow_plan']}")
                    if entry.get('mood_rating'):
                        prompt_parts.append(f"Mood: {entry['mood_rating']}/5")
                    if entry.get('productivity_self_rating'):
                        prompt_parts.append(f"Self-Productivity Rating: {entry['productivity_self_rating']}/5")
                    prompt_parts.append("")
        
        return "\n".join(prompt_parts)
    
    def create_report_structure(self, ai_response: str, intern_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create standardized report structure from AI response
        
        Args:
            ai_response: Raw AI response text
            intern_data: Original intern data for context
            
        Returns:
            Structured report dictionary
        """
        return {
            'summary': self._extract_summary(ai_response),
            'individual_analysis': self._extract_individual_analysis(ai_response, intern_data),
            'challenges': self._extract_challenges(ai_response),
            'recommendations': self._extract_recommendations(ai_response),
            'performance_scores': self._calculate_performance_scores(intern_data),
            'generated_at': time.strftime('%Y-%m-%d %H:%M:%S'),
            'provider': self.provider_name,
            'raw_response': ai_response
        }
    
    def _extract_summary(self, ai_response: str) -> str:
        """Extract overall summary from AI response"""
        # Try to find summary section
        lines = ai_response.split('\n')
        summary_started = False
        summary_lines = []
        
        for line in lines:
            if 'summary' in line.lower() or 'overview' in line.lower():
                summary_started = True
                continue
            if summary_started:
                if line.strip() and not line.startswith('#'):
                    summary_lines.append(line.strip())
                elif line.startswith('#') and summary_lines:
                    break
                    
        return ' '.join(summary_lines[:3]) if summary_lines else ai_response[:200] + "..."
    
    def _extract_individual_analysis(self, ai_response: str, intern_data: Dict[str, Any]) -> List[Dict]:
        """Extract individual intern analysis"""
        individual_analysis = []
        
        if 'interns_data' in intern_data:
            for intern_id, intern_info in intern_data['interns_data'].items():
                intern = intern_info['intern_info']
                # Simple analysis based on recent entries
                recent_entries = intern_info['logbook_entries'][-7:]
                
                avg_mood = sum(e.get('mood_rating', 3) for e in recent_entries if e.get('mood_rating')) / len(recent_entries) if recent_entries else 3
                avg_productivity = sum(e.get('productivity_self_rating', 3) for e in recent_entries if e.get('productivity_self_rating')) / len(recent_entries) if recent_entries else 3
                
                individual_analysis.append({
                    'intern_id': intern_id,
                    'intern_name': intern['name'],
                    'slt_id': intern['slt_id'],
                    'avg_mood': round(avg_mood, 1),
                    'avg_productivity': round(avg_productivity, 1),
                    'entries_count': len(recent_entries),
                    'analysis': f"Recent performance shows {'positive' if avg_productivity >= 3.5 else 'average'} productivity trends."
                })
                
        return individual_analysis
    
    def _extract_challenges(self, ai_response: str) -> List[str]:
        """Extract challenges from AI response"""
        challenges = []
        lines = ai_response.split('\n')
        challenges_started = False
        
        for line in lines:
            if 'challenge' in line.lower() or 'issue' in line.lower() or 'problem' in line.lower():
                challenges_started = True
                continue
            if challenges_started and line.strip():
                if line.startswith('-') or line.startswith('•') or line.startswith('*'):
                    challenges.append(line.strip().lstrip('-•* '))
                elif line.startswith('#') and challenges:
                    break
                    
        return challenges[:5]  # Limit to top 5 challenges
    
    def _extract_recommendations(self, ai_response: str) -> List[str]:
        """Extract recommendations from AI response"""
        recommendations = []
        lines = ai_response.split('\n')
        rec_started = False
        
        for line in lines:
            if 'recommend' in line.lower() or 'suggest' in line.lower() or 'improvement' in line.lower():
                rec_started = True
                continue
            if rec_started and line.strip():
                if line.startswith('-') or line.startswith('•') or line.startswith('*'):
                    recommendations.append(line.strip().lstrip('-•* '))
                elif line.startswith('#') and recommendations:
                    break
                    
        return recommendations[:5]  # Limit to top 5 recommendations
    
    def _calculate_performance_scores(self, intern_data: Dict[str, Any]) -> Dict[str, float]:
        """Calculate performance scores from intern data"""
        scores = {
            'overall_productivity': 0.0,
            'consistency': 0.0,
            'engagement': 0.0,
            'technical_progress': 0.0
        }
        
        if 'interns_data' in intern_data:
            total_interns = len(intern_data['interns_data'])
            if total_interns > 0:
                productivity_sum = 0
                consistency_sum = 0
                engagement_sum = 0
                
                for intern_info in intern_data['interns_data'].values():
                    entries = intern_info['logbook_entries']
                    if entries:
                        # Calculate productivity (based on self-ratings)
                        productivity_ratings = [e.get('productivity_self_rating', 3) for e in entries if e.get('productivity_self_rating')]
                        if productivity_ratings:
                            productivity_sum += sum(productivity_ratings) / len(productivity_ratings)
                        
                        # Calculate consistency (based on regular entries)
                        consistency_sum += min(len(entries) / 7.0 * 5, 5)  # Normalize to 5
                        
                        # Calculate engagement (based on mood ratings)
                        mood_ratings = [e.get('mood_rating', 3) for e in entries if e.get('mood_rating')]
                        if mood_ratings:
                            engagement_sum += sum(mood_ratings) / len(mood_ratings)
                
                scores['overall_productivity'] = round(productivity_sum / total_interns, 1)
                scores['consistency'] = round(consistency_sum / total_interns, 1)
                scores['engagement'] = round(engagement_sum / total_interns, 1)
                scores['technical_progress'] = round((scores['overall_productivity'] + scores['consistency']) / 2, 1)
        
        return scores
    
    def handle_api_error(self, error: Exception) -> Dict[str, Any]:
        """
        Handle API errors consistently across providers
        
        Args:
            error: Exception that occurred
            
        Returns:
            Standardized error response
        """
        self.last_error = str(error)
        return {
            'success': False,
            'error': str(error),
            'provider': self.provider_name,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
        }